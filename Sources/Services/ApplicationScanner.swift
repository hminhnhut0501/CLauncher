import Foundation
import AppKit

public final class ApplicationScanner: Sendable {
    public static let defaultSearchDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    public init() {}

    /// Scan all standard directories concurrently and return unique list of AppItems
    public func scanAllApplications() async -> [AppItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = self.performScan()
                continuation.resume(returning: apps)
            }
        }
    }

    private func performScan() -> [AppItem] {
        let fileManager = FileManager.default
        var collectedApps: [AppItem] = []
        var seenBundleIds = Set<String>()
        var seenPaths = Set<String>()

        for directory in Self.defaultSearchDirectories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            let appsInDir = scanDirectory(directory, fileManager: fileManager)
            for app in appsInDir {
                if let bundleId = app.bundleIdentifier {
                    if seenBundleIds.contains(bundleId) { continue }
                    seenBundleIds.insert(bundleId)
                } else {
                    if seenPaths.contains(app.url.path) { continue }
                }
                seenPaths.insert(app.url.path)
                collectedApps.append(app)
            }
        }

        // Sort alphabetically by localized display name
        return collectedApps.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Recursively scan a directory for .app bundles up to a max depth
    private func scanDirectory(_ directoryURL: URL, fileManager: FileManager, maxDepth: Int = 2) -> [AppItem] {
        var results: [AppItem] = []

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .contentModificationDateKey,
                .isHiddenKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return results
        }

        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path, with: "")
            let depth = relativePath.components(separatedBy: "/").count - 1
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            guard fileURL.pathExtension == "app" else { continue }

            if let appItem = parseAppBundle(at: fileURL, fileManager: fileManager) {
                results.append(appItem)
            }
            enumerator.skipDescendants()
        }

        return results
    }

    /// Parse bundle metadata efficiently
    private func parseAppBundle(at url: URL, fileManager: FileManager) -> AppItem? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        var displayName: String?
        var bundleIdentifier: String?
        var category: String?
        var isAgent = false

        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            displayName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String)
            bundleIdentifier = plist["CFBundleIdentifier"] as? String
            category = plist["LSApplicationCategoryType"] as? String
            isAgent = plist["LSUIElement"] as? Bool ?? false
        }

        let isSystemApp = url.path.hasPrefix("/System/")

        // Filter out background daemons that have no UI name
        if isAgent && isSystemApp && displayName == nil {
            return nil
        }

        let cleanName: String
        if let name = displayName, !name.isEmpty {
            cleanName = name
        } else {
            let systemName = fileManager.displayName(atPath: url.path)
            cleanName = systemName.isEmpty ? url.deletingPathExtension().lastPathComponent : systemName
        }

        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date

        // Check if custom icon was pasted via Finder (creates hidden "Icon\r" file)
        let iconURL = url.appendingPathComponent("Icon\r")
        let iconAttributes = try? fileManager.attributesOfItem(atPath: iconURL.path)
        let iconModDate = iconAttributes?[.modificationDate] as? Date
        let finalModDate = [modDate, iconModDate].compactMap { $0 }.max()

        return AppItem(
            name: cleanName,
            bundleIdentifier: bundleIdentifier,
            url: url,
            isSystemApp: isSystemApp,
            category: category,
            modificationDate: finalModDate
        )
    }
}
