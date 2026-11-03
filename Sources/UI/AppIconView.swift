import SwiftUI
import AppKit

public struct AppIconView: View {
    public let app: AppItem
    public var isFolderTarget: Bool = false
    public var animationDelay: Double = 0.0
    public var onHide: (() -> Void)? = nil
    public let onLaunch: () -> Void

    @State private var iconCGImage: CGImage?
    @State private var isHovered: Bool = false
    @State private var isLaunching: Bool = false
    @State private var isAppeared: Bool = false

    // Classic generous Apple Launchpad icon size
    private let iconSize: CGFloat = 108

    public init(
        app: AppItem,
        isFolderTarget: Bool = false,
        animationDelay: Double = 0.0,
        onHide: (() -> Void)? = nil,
        onLaunch: @escaping () -> Void
    ) {
        self.app = app
        self.isFolderTarget = isFolderTarget
        self.animationDelay = animationDelay
        self.onHide = onHide
        self.onLaunch = onLaunch
        _iconCGImage = State(initialValue: IconCacheService.shared.memoryCachedCGIcon(for: app))
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Folder Merge Target Highlight (When another app is dragged over this app)
                if isFolderTarget {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        )
                        .frame(width: iconSize + 16, height: iconSize + 16)
                        .offset(x: -8, y: -8)
                        .scaleEffect(1.08)
                        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isFolderTarget)
                }

                Group {
                    if let cgImage = iconCGImage {
                        // Direct GPU Metal Texture - Zero IconServices overhead!
                        Image(decorative: cgImage, scale: 2.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.35 : 0.20),
                    radius: isHovered ? 14 : 6,
                    x: 0,
                    y: isHovered ? 8 : 3
                )
                .scaleEffect(isLaunching ? 1.20 : (isFolderTarget ? 0.94 : (isHovered ? 1.08 : 1.0)))
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isFolderTarget)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovered)
            .animation(.spring(response: 0.22, dampingFraction: 0.5), value: isLaunching)

            // App Name Label with Dual Shadow
            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: 124)
                .shadow(color: Color.black.opacity(0.95), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.75), radius: 4, x: 0, y: 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .task(id: app.modificationDate) {
            if iconCGImage == nil {
                iconCGImage = await IconCacheService.shared.cgIcon(for: app)
            }
        }
    }

    public func launchApp() {
        guard !isLaunching else { return }
        isLaunching = true

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        // Crash-safe openApplication (nil completionHandler to prevent dispatch queue SIGTRAP assertion)
        NSWorkspace.shared.openApplication(at: app.url, configuration: config, completionHandler: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onLaunch()
            isLaunching = false
        }
    }
}
