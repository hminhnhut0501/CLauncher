import Foundation
import AppKit
@preconcurrency import QuickLookThumbnailing

public final class IconCacheService: @unchecked Sendable {
    public static let shared = IconCacheService()

    // RAM Cache limited to ~16 MB (max 64 icons simultaneously in RAM)
    private let memoryCache = NSCache<NSString, CGImage>()
    private let diskCacheDirectory: URL
    private let fileManager = FileManager.default

    // Standard Retina size: 100pt @ 2x = 200x200 px (160 KB per bitmap vs 1 MB formerly)
    private let targetIconSize: CGSize = CGSize(width: 100, height: 100)

    private init() {
        // High capacity RAM cache: stores up to 256 icons in GPU-ready format (~40MB max)
        memoryCache.countLimit = 256
        memoryCache.totalCostLimit = 64 * 1024 * 1024 // 64 MB max

        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TahoeLaunchpad/RasterIcons", isDirectory: true)
        self.diskCacheDirectory = cacheDir

        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    /// Fast synchronous RAM cache lookup for zero-latency SwiftUI initial state
    public func memoryCachedCGIcon(for app: AppItem) -> CGImage? {
        let key = generateCacheKey(for: app) as NSString
        return memoryCache.object(forKey: key)
    }

    /// High performance cached icon loader: RAM -> Disk -> Generator
    public func cgIcon(for app: AppItem) async -> CGImage? {
        let key = generateCacheKey(for: app)
        let nsKey = key as NSString

        // 1. Memory Cache Hit
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }

        // 2. Disk Cache Hit
        let diskURL = diskCacheDirectory.appendingPathComponent("\(key).png")
        if let diskImage = loadCGImageFromDisk(at: diskURL) {
            memoryCache.setObject(diskImage, forKey: nsKey, cost: diskImage.bytesPerRow * diskImage.height)
            return diskImage
        }

        // 3. Background Generation
        let generated = await generateRasterizedCGImage(for: app.url)
        if let cgImg = generated {
            memoryCache.setObject(cgImg, forKey: nsKey, cost: cgImg.bytesPerRow * cgImg.height)
            // Save to disk asynchronously in background
            saveCGImageToDisk(cgImg, at: diskURL)
        }
        return generated
    }

    /// Background preheat of initial visible apps only (prevents startup lockup & memory spikes)
    public func preheat(apps: [AppItem], limit: Int = 35) {
        let slice = Array(apps.prefix(limit))
        Task.detached(priority: .utility) {
            for app in slice {
                _ = await self.cgIcon(for: app)
            }
        }
    }

    /// Purges RAM cache when Launchpad window closes to maintain tiny background memory footprint
    public func evictMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// Complete cache reset (RAM and Disk)
    public func clearAllCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDirectory)
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    private func generateCacheKey(for app: AppItem) -> String {
        let modTime = app.modificationDate?.timeIntervalSince1970 ?? 0
        let raw = "\(app.id)_\(modTime)"
        let safeName = app.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        let hash = String(raw.hashValue)
        return "\(safeName)_\(hash)"
    }

    private func loadCGImageFromDisk(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func saveCGImageToDisk(_ image: CGImage, at url: URL) {
        DispatchQueue.global(qos: .background).async {
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
                return
            }
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }

    private func generateRasterizedCGImage(for url: URL) async -> CGImage? {
        // Fast path: QuickLook Thumbnail with exact 100pt x 2.0 scale (200x200 px)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: targetIconSize,
            scale: 2.0,
            representationTypes: .thumbnail
        )

        if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return thumbnail.cgImage
        }

        // Fallback: NSWorkspace with immediate concrete rasterization
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let rawIcon = NSWorkspace.shared.icon(forFile: url.path)
                rawIcon.size = CGSize(width: self.targetIconSize.width * 2, height: self.targetIconSize.height * 2)

                var rect = CGRect(origin: .zero, size: rawIcon.size)
                let cgImage = rawIcon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
                continuation.resume(returning: cgImage)
            }
        }
    }
}
