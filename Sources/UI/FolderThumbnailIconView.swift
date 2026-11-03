import SwiftUI
import AppKit

public struct FolderThumbnailIconView: View {
    public let folder: LaunchpadFolder
    public var isFolderTarget: Bool = false
    public var animationDelay: Double = 0.0
    public let onTap: () -> Void

    @State private var isHovered: Bool = false
    @State private var isAppeared: Bool = false

    // Classic generous Apple Launchpad folder size
    private let folderSize: CGFloat = 108

    public init(
        folder: LaunchpadFolder,
        isFolderTarget: Bool = false,
        animationDelay: Double = 0.0,
        onTap: @escaping () -> Void
    ) {
        self.folder = folder
        self.isFolderTarget = isFolderTarget
        self.animationDelay = animationDelay
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Folder Merge Target Highlight
                if isFolderTarget {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        )
                        .frame(width: folderSize + 16, height: folderSize + 16)
                        .scaleEffect(1.08)
                        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isFolderTarget)
                }

                let previewApps = Array(folder.apps.prefix(9))
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(25), spacing: 5), count: 3),
                    spacing: 5
                ) {
                    ForEach(previewApps) { app in
                        MiniIconView(app: app)
                    }
                }
                .padding(10)
            }
            .frame(width: folderSize, height: folderSize)
            .appleLiquidGlass(cornerRadius: 24, isHighlighted: isHovered || isFolderTarget)
            .scaleEffect(isFolderTarget ? 1.08 : (isHovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isFolderTarget)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovered)

            Text(folder.name)
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
    }
}

private struct MiniIconView: View {
    let app: AppItem
    @State private var image: CGImage?

    init(app: AppItem) {
        self.app = app
        self._image = State(initialValue: IconCacheService.shared.memoryCachedCGIcon(for: app))
    }

    var body: some View {
        Group {
            if let img = image {
                Image(decorative: img, scale: 2.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.3))
            }
        }
        .frame(width: 25, height: 25)
        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
        .task(id: app.modificationDate) {
            image = await IconCacheService.shared.cgIcon(for: app)
        }
    }
}
