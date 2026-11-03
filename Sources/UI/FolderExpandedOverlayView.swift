import SwiftUI
import AppKit

public struct FolderExpandedOverlayView: View {
    @Binding public var folder: LaunchpadFolder
    public let onLaunch: () -> Void
    public let onClose: () -> Void

    @State private var folderName: String = ""
    @State private var isAppeared: Bool = false
    @State private var folderPage: Int = 0
    @State private var folderDragOffset: CGFloat = 0
    @FocusState private var isTitleFocused: Bool

    // Folder drag-and-drop state
    @State private var activeTouchedApp: AppItem? = nil
    @State private var draggedFolderApp: AppItem? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var pressStartTime: Date? = nil
    private let layoutStore = FolderLayoutStore()
    @State private var isDraggingOutsideFolder: Bool = false
    @State private var edgeFolderPageWorkItem: DispatchWorkItem?

    // Apple Folder Classic Layout: 4 columns x 3 rows = 12 apps per page
    private let columnsCount: Int = 4
    private let rowsCount: Int = 3
    private var pageSize: Int { columnsCount * rowsCount }

    private var pages: [[AppItem]] {
        guard !folder.apps.isEmpty else { return [] }
        return stride(from: 0, to: folder.apps.count, by: pageSize).map {
            Array(folder.apps[$0..<min($0 + pageSize, folder.apps.count)])
        }
    }

    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.fixed(140), spacing: 24),
        count: 4
    )

    public init(
        folder: Binding<LaunchpadFolder>,
        onLaunch: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._folder = folder
        self.onLaunch = onLaunch
        self.onClose = onClose
        self._folderName = State(initialValue: folder.wrappedValue.name)
    }

    public var body: some View {
        ZStack {
            // Fullscreen Soft Backdrop (Click outside to dismiss; also drop target for extracting apps!)
            Color.black.opacity(isAppeared ? (isDraggingOutsideFolder ? 0.55 : 0.38) : 0.0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.2), value: isDraggingOutsideFolder)

            // Apple Native Liquid Glass Folder Window (780pt width)
            VStack(spacing: 18) {
                // 1. Folder Title Bar
                TextField("Folder Name", text: $folderName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 32, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .focused($isTitleFocused)
                    .onSubmit {
                        commitTitle()
                    }
                    .onChange(of: isTitleFocused) { _, focused in
                        if !focused {
                            commitTitle()
                        }
                    }
                    .frame(maxWidth: 480)
                    .padding(.top, 32)
                    .shadow(color: Color.black.opacity(0.85), radius: 3, y: 1)

                // 2. Strict Clipped Paginated Grid Area (Spacious 470pt height)
                GeometryReader { geo in
                    let folderWidth = geo.size.width

                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<pages.count, id: \.self) { pageIndex in
                            VStack(spacing: 0) {
                                LazyVGrid(columns: gridColumns, alignment: .center, spacing: 22) {
                                    ForEach(pages[pageIndex]) { app in
                                        let isBeingDragged = draggedFolderApp?.id == app.id
                                        AppIconView(app: app) {
                                            onLaunch()
                                        }
                                        .opacity(isBeingDragged ? 0.18 : 1.0)
                                        .background(
                                            GeometryReader { cGeo in
                                                Color.clear.preference(
                                                    key: FolderCellFramePreferenceKey.self,
                                                    value: [app.id: cGeo.frame(in: .named("FolderOverlaySpace"))]
                                                )
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 40)
                                .padding(.top, 8)
                                Spacer(minLength: 0)
                            }
                            .frame(width: folderWidth)
                        }
                    }
                    .offset(x: -CGFloat(folderPage) * folderWidth + folderDragOffset)
                }
                .frame(height: 480)
                .clipped()

                // 3. Dedicated Bottom Pagination Area
                if pages.count > 1 {
                    HStack(spacing: 11) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            let isSelected = folderPage == index
                            Capsule()
                                .fill(isSelected ? Color.white : Color.white.opacity(0.35))
                                .frame(width: isSelected ? 24 : 8, height: 8)
                                .shadow(color: isSelected ? Color.white.opacity(0.85) : Color.black.opacity(0.3), radius: 5, y: 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let diff = index - folderPage
                                    if diff != 0 {
                                        folderPage = index
                                        folderDragOffset = CGFloat(diff) * 780
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            folderDragOffset = 0
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .appleLiquidGlass(cornerRadius: 16)
                    .padding(.bottom, 26)
                } else {
                    Spacer().frame(height: 22)
                }
            }
            .frame(width: 780)
            .appleLiquidGlass(cornerRadius: 38)
            .scaleEffect(isAppeared ? (isDraggingOutsideFolder ? 0.94 : 1.0) : 0.90)
            .opacity(isAppeared ? 1.0 : 0.0)
            .background(
                GeometryReader { wGeo in
                    Color.clear.preference(
                        key: FolderWindowFramePreferenceKey.self,
                        value: wGeo.frame(in: .named("FolderOverlaySpace"))
                    )
                }
            )

            // 4. Floating Dragged Icon inside/outside Folder
            if let dragged = draggedFolderApp {
                FloatingFolderAppIconView(app: dragged, isOutside: isDraggingOutsideFolder)
                    .position(dragLocation)
                    .zIndex(9999)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "FolderOverlaySpace")
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("FolderOverlaySpace"))
                .onChanged { value in
                    handleFolderDragChanged(value)
                }
                .onEnded { value in
                    handleFolderDragEnded(value)
                }
        )
        .onPreferenceChange(FolderCellFramePreferenceKey.self) { frames in
            layoutStore.cellFrames = frames
        }
        .onPreferenceChange(FolderWindowFramePreferenceKey.self) { frame in
            layoutStore.windowFrame = frame
        }
        .onAppear {
            ScrollEventCoordinator.shared.isFolderActive = true
            setupFolderScrollHooks()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isAppeared = true
            }
        }
        .onDisappear {
            ScrollEventCoordinator.shared.isFolderActive = false
        }
        .onChange(of: folder.name) { _, newName in
            if !isTitleFocused && folderName != newName {
                folderName = newName
            }
        }
    }

    private func handleFolderDragChanged(_ value: DragGesture.Value) {
        let currentPoint = value.location
        let distance = hypot(value.translation.width, value.translation.height)

        if pressStartTime == nil {
            pressStartTime = Date()
            activeTouchedApp = folder.apps.first(where: {
                layoutStore.cellFrames[$0.id]?.contains(value.startLocation) == true
            })
        }

        guard let touched = activeTouchedApp else { return }

        if distance > 6 {
            if draggedFolderApp?.id != touched.id {
                draggedFolderApp = touched
            }
            dragLocation = currentPoint

            // Compute robust folder window bounds
            let screenW = NSScreen.main?.frame.width ?? 1440
            let screenH = NSScreen.main?.frame.height ?? 900
            let fallbackRect = CGRect(x: (screenW - 780) / 2, y: (screenH - 580) / 2, width: 780, height: 580)
            let windowRect = layoutStore.windowFrame.width > 200 ? layoutStore.windowFrame : fallbackRect

            // 1. Check if dragged completely OUTSIDE the folder window (extraction target)
            let isOutside = currentPoint.x < windowRect.minX - 45 ||
                            currentPoint.x > windowRect.maxX + 45 ||
                            currentPoint.y < windowRect.minY - 45 ||
                            currentPoint.y > windowRect.maxY + 45

            if isOutside {
                edgeFolderPageWorkItem?.cancel()
                edgeFolderPageWorkItem = nil
                if !isDraggingOutsideFolder {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                        isDraggingOutsideFolder = true
                    }
                }
            } else {
                if isDraggingOutsideFolder {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                        isDraggingOutsideFolder = false
                    }
                }

                // 2. Check Edge-Paging inside the folder window margins
                let leftEdgeTrigger = windowRect.minX + 110
                let rightEdgeTrigger = windowRect.maxX - 110

                if currentPoint.x < leftEdgeTrigger && folderPage > 0 {
                    triggerFolderEdgePage(direction: -1, touchedAppId: touched.id)
                } else if currentPoint.x > rightEdgeTrigger && folderPage < pages.count - 1 {
                    triggerFolderEdgePage(direction: 1, touchedAppId: touched.id)
                } else {
                    edgeFolderPageWorkItem?.cancel()
                    edgeFolderPageWorkItem = nil

                    // 3. Live reordering between apps on current page
                    if let targetApp = folder.apps.first(where: { $0.id != touched.id && layoutStore.cellFrames[$0.id]?.contains(currentPoint) == true }) {
                        if let fromIdx = folder.apps.firstIndex(where: { $0.id == touched.id }),
                           let toIdx = folder.apps.firstIndex(where: { $0.id == targetApp.id }) {
                            LaunchpadStore.shared.reorderAppInFolder(folderId: folder.id, fromIndex: fromIdx, toIndex: toIdx)
                            self.folder = LaunchpadStore.shared.activeFolder ?? folder
                        }
                    }
                }
            }
        }
    }

    private func triggerFolderEdgePage(direction: Int, touchedAppId: String) {
        guard edgeFolderPageWorkItem == nil else { return }
        let targetPage = folderPage + direction
        guard targetPage >= 0 && targetPage < pages.count else { return }

        let work = DispatchWorkItem {
            let folderWidth: CGFloat = 780
            self.folderPage = targetPage
            self.folderDragOffset = (direction > 0 ? folderWidth : -folderWidth)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                self.folderDragOffset = 0
            }

            // Move the dragged app into the target page so it belongs to that page
            if let fromIdx = self.folder.apps.firstIndex(where: { $0.id == touchedAppId }) {
                let toIdx: Int
                if direction > 0 {
                    toIdx = min(targetPage * self.pageSize, self.folder.apps.count - 1)
                } else {
                    toIdx = min((targetPage + 1) * self.pageSize - 1, self.folder.apps.count - 1)
                }

                if fromIdx != toIdx {
                    LaunchpadStore.shared.reorderAppInFolder(folderId: self.folder.id, fromIndex: fromIdx, toIndex: toIdx)
                    self.folder = LaunchpadStore.shared.activeFolder ?? self.folder
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.edgeFolderPageWorkItem = nil
            }
        }
        edgeFolderPageWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }

    private func handleFolderDragEnded(_ value: DragGesture.Value) {
        edgeFolderPageWorkItem?.cancel()
        edgeFolderPageWorkItem = nil

        let elapsed = Date().timeIntervalSince(pressStartTime ?? Date())
        let distance = hypot(value.translation.width, value.translation.height)
        let touched = activeTouchedApp
        let wasDragging = draggedFolderApp != nil
        let draggedOut = isDraggingOutsideFolder

        pressStartTime = nil
        activeTouchedApp = nil

        if !wasDragging && distance < 6 && elapsed < 0.30 {
            if let app = touched {
                // Clicked on app: launch it
                launchApp(app)
            } else {
                // Clicked on background: dismiss folder
                dismiss()
            }
        } else if wasDragging, let app = touched {
            if draggedOut {
                // Dragged OUT of folder: remove from folder and place onto main screen!
                LaunchpadStore.shared.removeAppFromFolder(app: app, folderId: folder.id)
                dismiss()
            } else {
                LaunchpadStore.shared.saveLayout()
            }
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            draggedFolderApp = nil
            isDraggingOutsideFolder = false
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

    private func setupFolderScrollHooks() {
        ScrollEventCoordinator.shared.onFolderScrollDelta = { delta in
            let atStart = folderPage == 0 && delta > 0
            let atEnd = folderPage >= pages.count - 1 && delta < 0
            let resistance: CGFloat = (atStart || atEnd) ? 0.30 : 1.0
            folderDragOffset = delta * resistance
        }

        ScrollEventCoordinator.shared.onFolderScrollEnded = { finalDelta, velocity in
            let threshold: CGFloat = 35.0
            let isFlickNext = velocity < -300
            let isFlickPrev = velocity > 300
            let shouldNext = (finalDelta < -threshold || isFlickNext) && folderPage < pages.count - 1
            let shouldPrev = (finalDelta > threshold || isFlickPrev) && folderPage > 0

            let folderWidth: CGFloat = 780
            if shouldNext {
                folderPage += 1
                folderDragOffset = folderWidth + finalDelta
            } else if shouldPrev {
                folderPage -= 1
                folderDragOffset = -folderWidth + finalDelta
            }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                folderDragOffset = 0
            }
        }

        ScrollEventCoordinator.shared.onFolderArrowKey = { direction in
            let folderWidth: CGFloat = 780
            if direction > 0 && folderPage < pages.count - 1 {
                folderPage += 1
                folderDragOffset = folderWidth
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    folderDragOffset = 0
                }
            } else if direction < 0 && folderPage > 0 {
                folderPage -= 1
                folderDragOffset = -folderWidth
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    folderDragOffset = 0
                }
            }
        }
    }

    private func commitTitle() {
        isTitleFocused = false
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            folder.name = trimmed
            LaunchpadStore.shared.updateFolderName(folderId: folder.id, newName: trimmed)
        }
    }

    private func dismiss() {
        commitTitle()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            isAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onClose()
        }
    }
}

public final class FolderLayoutStore: @unchecked Sendable {
    public var cellFrames: [String: CGRect] = [:]
    public var windowFrame: CGRect = .zero
}

public struct FolderCellFramePreferenceKey: PreferenceKey {
    public static let defaultValue: [String: CGRect] = [:]
    public static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct FolderWindowFramePreferenceKey: PreferenceKey {
    public static let defaultValue: CGRect = .zero
    public static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct FloatingFolderAppIconView: View {
    let app: AppItem
    var isOutside: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let cgImage = IconCacheService.shared.memoryCachedCGIcon(for: app) {
                Image(decorative: cgImage, scale: 2.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 108, height: 108)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 108, height: 108)
            }

            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 124)
                .shadow(color: Color.black.opacity(0.95), radius: 1, x: 0, y: 1)

            if isOutside {
                Text("Release to extract to Home")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
            }
        }
        .scaleEffect(isOutside ? 1.20 : 1.14)
        .shadow(color: isOutside ? Color.cyan.opacity(0.6) : Color.black.opacity(0.55), radius: 26, x: 0, y: 16)
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isOutside)
    }
}
