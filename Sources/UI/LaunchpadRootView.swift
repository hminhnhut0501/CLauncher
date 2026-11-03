import SwiftUI
import AppKit

public struct LaunchpadRootView: View {
    @ObservedObject private var store = LaunchpadStore.shared
    public let onDismiss: () -> Void

    @State private var isViewLoaded: Bool = false

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var dockHeight: CGFloat {
        NSScreen.main?.visibleFrame.origin.y ?? 0
    }

    private func handleBackgroundTap() {
        if store.activeFolder != nil {
            store.activeFolder = nil
        } else {
            onDismiss()
        }
    }

    public var body: some View {
        ZStack {
            // 1. Pure Apple Native Full-screen Blur (Clicking empty background dismisses)
            VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    handleBackgroundTap()
                }

            // 2. Main Traditional macOS Launchpad Layout
            VStack(spacing: 8) {
                // Top Search Bar area
                HStack {
                    Spacer()
                    LiquidGlassSearchBar(text: $store.searchText) {
                        store.launchFirstSearchResult()
                    }
                    Spacer()
                }
                .padding(.top, 28)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Click on the empty margin around the search bar dismisses
                    handleBackgroundTap()
                }

                // Grid Area
                if store.visibleItems.isEmpty && !store.searchText.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "questionmark.app.dashed")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.35))
                        Text("No applications found for \"\(store.searchText)\"")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleBackgroundTap()
                    }
                } else {
                    AppGridView(
                        onLaunch: onDismiss,
                        onOpenFolder: { folder in
                            store.activeFolder = folder
                        },
                        onTapBackground: {
                            handleBackgroundTap()
                        }
                    )
                    .opacity(store.activeFolder != nil ? 0.15 : 1.0)
                    .scaleEffect(store.activeFolder != nil ? 0.96 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.85), value: store.activeFolder != nil)
                }

                // 3. Guaranteed Floating Page Indicator Dots (Directly below grid, safely above Dock)
                if store.pages.count > 1 && store.searchText.isEmpty && store.activeFolder == nil {
                    HStack(spacing: 10) {
                        ForEach(0..<store.pages.count, id: \.self) { index in
                            let isSelected = store.currentPage == index
                            Capsule()
                                .fill(isSelected ? Color.white : Color.white.opacity(0.35))
                                .frame(width: isSelected ? 22 : 7, height: 7)
                                .shadow(color: isSelected ? Color.white.opacity(0.85) : Color.black.opacity(0.3), radius: isSelected ? 5 : 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.goToPage(index)
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .appleLiquidGlass(cornerRadius: 14)
                    .padding(.bottom, max(28, dockHeight + 14))
                } else {
                    Spacer().frame(height: max(28, dockHeight + 14))
                }
            }
            .scaleEffect(isViewLoaded ? 1.0 : 0.94)
            .opacity(isViewLoaded ? 1.0 : 0.0)

            // 4. Active Folder Expanded Overlay
            if let folder = store.activeFolder {
                FolderExpandedOverlayView(
                    folder: Binding(
                        get: { folder },
                        set: { updated in
                            store.activeFolder = updated
                            if let idx = store.items.firstIndex(where: {
                                if case .folder(let f) = $0 { return f.id == updated.id }
                                return false
                            }) {
                                store.items[idx] = .folder(updated)
                                store.saveLayout()
                            }
                        }
                    ),
                    onLaunch: onDismiss,
                    onClose: {
                        store.activeFolder = nil
                    }
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                isViewLoaded = true
            }
        }
    }
}
