import SwiftUI
import AppKit

public struct AppGridView: View {
    @ObservedObject private var store = LaunchpadStore.shared
    @ObservedObject private var motion = GridMotionStore.shared
    public let onLaunch: () -> Void
    public let onOpenFolder: (LaunchpadFolder) -> Void
    public let onTapBackground: () -> Void

    @State private var activeTouchedItem: LaunchpadItem? = nil
    @State private var pressStartTime: Date? = nil
    @State private var edgePageWorkItem: DispatchWorkItem?
    @State private var mergeDwellWorkItem: DispatchWorkItem?
    @State private var pendingMergeTargetId: String? = nil
    @State private var pressHoldWorkItem: DispatchWorkItem?
    @State private var currentDragPoint: CGPoint = .zero
    private let layoutStore = GridLayoutStore()

    public init(
        onLaunch: @escaping () -> Void,
        onOpenFolder: @escaping (LaunchpadFolder) -> Void,
        onTapBackground: @escaping () -> Void
    ) {
        self.onLaunch = onLaunch
        self.onOpenFolder = onOpenFolder
        self.onTapBackground = onTapBackground
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 100), spacing: 20),
            count: store.columnsCount
        )
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width

            ZStack(alignment: .topLeading) {
                // 1. Horizontally Paginated Grid Pages
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<store.pages.count, id: \.self) { pageIndex in
                        VStack(spacing: 0) {
                            LazyVGrid(columns: gridColumns, alignment: .center, spacing: 18) {
                                ForEach(store.pages[pageIndex], id: \.id) { item in
                                    let isBeingDragged = store.draggedItem?.id == item.id
                                    let isFolderTarget = motion.hoverFolderTargetId == item.id

                                    cellView(item: item, isFolderTarget: isFolderTarget)
                                        .opacity(isBeingDragged ? 0.18 : 1.0)
                                        .background(
                                            GeometryReader { geo in
                                                if pageIndex == store.currentPage {
                                                    Color.clear.preference(
                                                        key: CellFramePreferenceKey.self,
                                                        value: [item.id: geo.frame(in: .named("CurrentPageContentSpace"))]
                                                    )
                                                }
                                            }
                                        )
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.top, 4)
                            Spacer(minLength: 0)
                        }
                        .frame(width: totalWidth)
                        .coordinateSpace(name: pageIndex == store.currentPage ? "CurrentPageContentSpace" : "InactivePageSpace")
                    }
                }
                .offset(x: -CGFloat(store.currentPage) * totalWidth + motion.dragOffset)

                // 2. Dedicated 120Hz Floating Dragged Representation (Absolute pixel-perfect cursor tracking)
                if let dragged = store.draggedItem {
                    FloatingDraggedIconView(item: dragged)
                        .position(motion.dragLocation)
                        .zIndex(9999)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "AppGridViewSpace")
            .contentShape(Rectangle())
            // Single container gesture: 100% immune to cell view hierarchy invalidations!
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("AppGridViewSpace"))
                    .onChanged { value in
                        handleDragChanged(value, totalWidth: totalWidth)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
        }
        .onAppear {
            store.pageWidth = NSScreen.main?.frame.width ?? 1440
        }
        .onPreferenceChange(CellFramePreferenceKey.self) { frames in
            layoutStore.cellFrames = frames
        }
    }

    @ViewBuilder
    private func cellView(item: LaunchpadItem, isFolderTarget: Bool) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                isFolderTarget: isFolderTarget,
                onHide: { store.hideApp(app) },
                onLaunch: onLaunch
            )
        case .folder(let folder):
            FolderThumbnailIconView(
                folder: folder,
                isFolderTarget: isFolderTarget,
                onTap: { onOpenFolder(folder) }
            )
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, totalWidth: CGFloat) {
        // In search mode, disable reordering and folder creation (strictly click-to-launch)
        guard store.searchText.isEmpty else { return }

        store.pageWidth = totalWidth
        let currentPoint = value.location
        let distance = hypot(value.translation.width, value.translation.height)
        let geometry = GridGeometry(totalWidth: totalWidth, columns: store.columnsCount, rows: store.rowsCount)
        let currentPageItems = store.pages.indices.contains(store.currentPage) ? store.pages[store.currentPage] : []

        // Local point relative to current page content (compensating for live trackpad swipe offset)
        let localPoint = CGPoint(x: currentPoint.x - motion.dragOffset, y: currentPoint.y)

        if pressStartTime == nil {
            pressStartTime = Date()
            currentDragPoint = currentPoint

            // Dual Hit-Testing:
            // 1. Pixel-perfect preference frame lookup (measured directly on rendered view)
            if let hitByFrame = currentPageItems.first(where: {
                layoutStore.cellFrames[$0.id]?.contains(localPoint) == true
            }) {
                activeTouchedItem = hitByFrame
            } else if let idx = geometry.itemIndex(at: localPoint, maxItems: currentPageItems.count) {
                // 2. Mathematical GridGeometry fallback
                activeTouchedItem = currentPageItems[idx]
            }

            // Start Press & Hold (Nhấn Giữ) Timer (0.35s standard Springboard dwell):
            // After holding down for 0.35s without moving, the icon lifts up into hand with haptic feedback!
            if let touched = activeTouchedItem {
                let holdWork = DispatchWorkItem { [weak motion] in
                    guard self.activeTouchedItem?.id == touched.id, self.store.draggedItem == nil else { return }
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.70)) {
                        self.store.draggedItem = touched
                        motion?.dragLocation = self.currentDragPoint
                    }
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
                pressHoldWorkItem = holdWork
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: holdWork)
            }
        }

        guard let touched = activeTouchedItem else { return }
        currentDragPoint = currentPoint

        // When moving beyond 7pt, cancel hold timer and enter live drag immediately
        if distance > 7 {
            pressHoldWorkItem?.cancel()
            pressHoldWorkItem = nil

            if store.draggedItem?.id != touched.id {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.70)) {
                    store.draggedItem = touched
                }
            }
            motion.dragLocation = currentPoint

            // 1. Edge-Paging across screens while dragging near left/right screen borders
            let edgeMargin: CGFloat = 65.0
            if currentPoint.x < edgeMargin && store.currentPage > 0 {
                cancelMergeDwell()
                triggerEdgePage(direction: -1)
            } else if currentPoint.x > totalWidth - edgeMargin && store.currentPage < store.pages.count - 1 {
                cancelMergeDwell()
                triggerEdgePage(direction: 1)
            } else {
                edgePageWorkItem?.cancel()
                edgePageWorkItem = nil
            }

            // 2. Collision check against items on CURRENT PAGE
            var hitItem: LaunchpadItem? = nil
            if let hitIdx = geometry.itemIndex(at: localPoint, maxItems: currentPageItems.count) {
                let cand = currentPageItems[hitIdx]
                if cand.id != touched.id {
                    hitItem = cand
                }
            } else if let cand = currentPageItems.first(where: { $0.id != touched.id && layoutStore.cellFrames[$0.id]?.contains(localPoint) == true }) {
                hitItem = cand
            }

            if let hit = hitItem {
                let targetFrame = layoutStore.cellFrames[hit.id] ?? geometry.frame(for: currentPageItems.firstIndex(where: { $0.id == hit.id }) ?? 0)
                let center = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
                let distToCenter = hypot(localPoint.x - center.x, localPoint.y - center.y)

                let isDraggingApp: Bool = {
                    if case .app = touched { return true }
                    return false
                }()

                if !isDraggingApp {
                    // DRAGGING A FOLDER:
                    // Folders never merge into other folders or apps.
                    // Instant, frictionless reordering!
                    cancelMergeDwell()
                    store.moveItem(from: touched.id, to: hit.id)
                } else {
                    // DRAGGING AN APP:
                    let isHitFolder: Bool = {
                        if case .folder = hit { return true }
                        return false
                    }()

                    if isHitFolder {
                        // CASE A: DRAGGING AN APP OVER AN EXISTING FOLDER!
                        // Wide, generous drop zone (up to 75pt radius = entire folder tile)
                        if distToCenter <= 75 {
                            // Instantly highlight folder as absorb target
                            if motion.hoverFolderTargetId != hit.id {
                                cancelMergeDwell()
                                withAnimation(.spring(response: 0.20, dampingFraction: 0.68)) {
                                    motion.hoverFolderTargetId = hit.id
                                }
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            }
                        } else {
                            // Outside folder zone (> 75pt)
                            if motion.hoverFolderTargetId == hit.id {
                                cancelMergeDwell()
                            }
                            // Only reorder if dragging far past the folder (> 85pt)
                            if distToCenter > 85 {
                                store.moveItem(from: touched.id, to: hit.id)
                            }
                        }
                    } else {
                        // CASE B: DRAGGING AN APP OVER ANOTHER APP (Create New Folder)!
                        // Generous zone (up to 62pt)
                        if distToCenter <= 62 {
                            if pendingMergeTargetId != hit.id && motion.hoverFolderTargetId != hit.id {
                                cancelMergeDwell()
                                pendingMergeTargetId = hit.id

                                let targetId = hit.id
                                let work = DispatchWorkItem { [weak motion] in
                                    guard self.pendingMergeTargetId == targetId else { return }
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                                        motion?.hoverFolderTargetId = targetId
                                    }
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                }
                                mergeDwellWorkItem = work
                                // Fast, responsive 0.22s dwell timer
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
                            }
                        } else {
                            // User is dragging past outer perimeter (> 65pt):
                            // Cancel merge dwell and reorder slots immediately!
                            cancelMergeDwell()
                            store.moveItem(from: touched.id, to: hit.id)
                        }
                    }
                }
            } else {
                cancelMergeDwell()
            }
        }
    }

    private func cancelMergeDwell() {
        mergeDwellWorkItem?.cancel()
        mergeDwellWorkItem = nil
        pendingMergeTargetId = nil
        if motion.hoverFolderTargetId != nil {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.75)) {
                motion.hoverFolderTargetId = nil
            }
        }
    }

    private func triggerEdgePage(direction: Int) {
        guard edgePageWorkItem == nil else { return }
        let targetPage = store.currentPage + direction
        guard targetPage >= 0 && targetPage < store.pages.count else { return }

        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                store.currentPage = targetPage
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                edgePageWorkItem = nil
            }
        }
        edgePageWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40, execute: work)
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        pressHoldWorkItem?.cancel()
        pressHoldWorkItem = nil
        edgePageWorkItem?.cancel()
        edgePageWorkItem = nil
        mergeDwellWorkItem?.cancel()
        mergeDwellWorkItem = nil

        let elapsed = Date().timeIntervalSince(pressStartTime ?? Date())
        let distance = hypot(value.translation.width, value.translation.height)
        let touched = activeTouchedItem
        let wasDragging = store.draggedItem != nil
        let targetId = motion.hoverFolderTargetId

        pressStartTime = nil
        activeTouchedItem = nil
        pendingMergeTargetId = nil

        let isClick = distance < 8 && (!wasDragging || elapsed < 0.38)

        if isClick {
            // Quick or deliberate Click / Tap
            if let item = touched {
                switch item {
                case .app(let app):
                    launchApp(app)
                case .folder(let folder):
                    onOpenFolder(folder)
                }
            } else {
                // Clicked on empty space: dismiss
                onTapBackground()
            }
        } else if wasDragging, let dragged = touched {
            // Drop after dragging
            if let targetId = targetId {
                store.mergeIntoFolder(sourceId: dragged.id, targetId: targetId)
            } else {
                store.saveLayout()
            }
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            store.draggedItem = nil
            motion.hoverFolderTargetId = nil
        }
    }

    private func launchApp(_ app: AppItem) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: config, completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onLaunch()
        }
    }
}

public struct GridGeometry {
    public let totalWidth: CGFloat
    public let columns: Int
    public let rows: Int
    public let padH: CGFloat = 48
    public let padTop: CGFloat = 4
    public let spacingX: CGFloat = 20
    public let spacingY: CGFloat = 18
    public let cellHeight: CGFloat = 144

    public var colWidth: CGFloat {
        let available = totalWidth - (padH * 2) - CGFloat(max(1, columns - 1)) * spacingX
        return available / CGFloat(max(1, columns))
    }

    public func frame(for index: Int) -> CGRect {
        let col = index % max(1, columns)
        let row = index / max(1, columns)
        let x = padH + CGFloat(col) * (colWidth + spacingX)
        let y = padTop + CGFloat(row) * (cellHeight + spacingY)
        return CGRect(x: x, y: y, width: colWidth, height: cellHeight)
    }

    public func itemIndex(at point: CGPoint, maxItems: Int) -> Int? {
        guard point.x >= padH && point.y >= padTop else { return nil }
        let col = Int((point.x - padH) / (colWidth + spacingX))
        let row = Int((point.y - padTop) / (cellHeight + spacingY))
        guard col >= 0 && col < columns && row >= 0 && row < rows else { return nil }
        let index = row * columns + col
        guard index >= 0 && index < maxItems else { return nil }
        return index
    }
}

public final class GridLayoutStore: @unchecked Sendable {
    public var cellFrames: [String: CGRect] = [:]
}

// Global Frame Preference for 100% accurate collision & folder creation detection
public struct CellFramePreferenceKey: PreferenceKey {
    public static let defaultValue: [String: CGRect] = [:]
    public static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// 120Hz Floating Dragged Representation
private struct FloatingDraggedIconView: View {
    let item: LaunchpadItem
    @State private var iconCGImage: CGImage?

    init(item: LaunchpadItem) {
        self.item = item
        if case .app(let app) = item {
            self._iconCGImage = State(initialValue: IconCacheService.shared.memoryCachedCGIcon(for: app))
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            switch item {
            case .app:
                if let cgImage = iconCGImage {
                    Image(decorative: cgImage, scale: 2.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 108, height: 108)
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 108, height: 108)
                }
            case .folder(let folder):
                FolderThumbnailIconView(folder: folder, onTap: {})
            }

            Text(item.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 124)
                .shadow(color: Color.black.opacity(0.95), radius: 1, x: 0, y: 1)
        }
        .scaleEffect(1.15)
        .shadow(color: Color.black.opacity(0.55), radius: 26, x: 0, y: 16)
        .task {
            if case .app(let app) = item, iconCGImage == nil {
                iconCGImage = await IconCacheService.shared.cgIcon(for: app)
            }
        }
    }
}
