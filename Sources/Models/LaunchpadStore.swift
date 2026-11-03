import Foundation
import SwiftUI
import AppKit

@MainActor
public final class LaunchpadStore: ObservableObject {
    public static let shared = LaunchpadStore()

    @Published public var apps: [AppItem] = []
    @Published public var items: [LaunchpadItem] = []
    @Published public var currentPage: Int = 0
    @Published public var searchText: String = ""
    @Published public var activeFolder: LaunchpadFolder? = nil
    @Published public var draggedItem: LaunchpadItem? = nil
    public var pageWidth: CGFloat = NSScreen.main?.frame.width ?? 1440
    private var lastSwapTime: Date = .distantPast
    @Published public var columnsCount: Int = 7
    @Published public var rowsCount: Int = 5
    @Published public var hiddenBundleIds: Set<String> = []

    // Backward-compatible accessors forwarding directly to high-frequency GridMotionStore
    public var dragOffset: CGFloat {
        get { GridMotionStore.shared.dragOffset }
        set { GridMotionStore.shared.dragOffset = newValue }
    }
    public var dragLocation: CGPoint {
        get { GridMotionStore.shared.dragLocation }
        set { GridMotionStore.shared.dragLocation = newValue }
    }
    public var hoverFolderTargetId: String? {
        get { GridMotionStore.shared.hoverFolderTargetId }
        set { GridMotionStore.shared.hoverFolderTargetId = newValue }
    }

    public var pageSize: Int { columnsCount * rowsCount }

    public var visibleItems: [LaunchpadItem] {
        let current = items.filter { item in
            switch item {
            case .app(let a):
                return !hiddenBundleIds.contains(a.id)
            case .folder(let f):
                return !f.apps.isEmpty
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return current }

        return SmartSearchEngine.shared.search(query: query, in: items, hiddenIds: hiddenBundleIds)
    }

    public func launchFirstSearchResult() {
        guard let first = visibleItems.first else { return }
        switch first {
        case .app(let app):
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: app.url, configuration: config, completionHandler: nil)
            LaunchpadWindowController.shared.hide()
        case .folder(let folder):
            self.activeFolder = folder
        }
    }

    public var pages: [[LaunchpadItem]] {
        let list = visibleItems
        guard !list.isEmpty else { return [] }
        return stride(from: 0, to: list.count, by: pageSize).map {
            Array(list[$0..<min($0 + pageSize, list.count)])
        }
    }

    private init() {
        loadConfiguration()
    }

    public func loadConfiguration() {
        let config = LayoutPersistenceService.shared.load()
        self.columnsCount = config.columnsCount
        self.rowsCount = config.rowsCount
        self.hiddenBundleIds = Set(config.hiddenAppIds)
    }

    public func setApps(_ newApps: [AppItem]) {
        self.apps = newApps
        rebuildItems()
    }

    public func rebuildItems() {
        loadConfiguration()
        let config = LayoutPersistenceService.shared.load()

        var appMap: [String: AppItem] = [:]
        for app in apps {
            appMap[app.id] = app
        }

        var reconstructed: [LaunchpadItem] = []
        var assignedIds = Set<String>()

        // 1. Rebuild Saved Folders
        for sf in config.folders {
            let children = sf.appIds.compactMap { appMap[$0] }
            for c in children { assignedIds.insert(c.id) }
            let folder = LaunchpadFolder(id: sf.id, name: sf.name, apps: children)
            reconstructed.append(.folder(folder))
        }

        // 2. Default Utilities Folder if none saved
        if config.folders.isEmpty {
            let utils = apps.filter { $0.url.path.contains("/Utilities") }
            if !utils.isEmpty {
                for u in utils { assignedIds.insert(u.id) }
                let utilFolder = LaunchpadFolder(name: "Utilities", apps: utils)
                reconstructed.append(.folder(utilFolder))
            }
        }

        // 3. Append remaining apps
        for app in apps where !assignedIds.contains(app.id) {
            reconstructed.append(.app(app))
        }

        // 4. Apply saved custom order if present
        if !config.itemOrder.isEmpty {
            let orderMap = Dictionary(uniqueKeysWithValues: config.itemOrder.enumerated().map { ($1, $0) })
            reconstructed.sort { a, b in
                let orderA = orderMap[a.id] ?? 999999
                let orderB = orderMap[b.id] ?? 999999
                return orderA < orderB
            }
        }

        self.items = reconstructed
        // Clamp currentPage if it exceeds available pages
        let totalPages = max(1, Int(ceil(Double(reconstructed.count) / Double(pageSize))))
        if currentPage >= totalPages {
            currentPage = totalPages - 1
        }

        print("[LaunchpadStore] Rebuilt items: \(reconstructed.count) items, \(pages.count) pages.")
    }

    // Interactive Drag / Scroll handling with ProMotion 120Hz continuous physics
    public func handleScrollDelta(_ delta: CGFloat) {
        guard activeFolder == nil else { return }
        GridMotionStore.shared.updateScrollDelta(delta, totalPages: pages.count, currentPage: currentPage)
    }

    public func handleScrollEnded(_ finalDelta: CGFloat, velocity: CGFloat = 0) {
        guard activeFolder == nil else { return }
        let total = pages.count
        guard total > 1 else {
            GridMotionStore.shared.resetOffset(animated: true)
            return
        }

        let threshold: CGFloat = 35.0
        let isFlickNext = velocity < -300
        let isFlickPrev = velocity > 300
        let shouldNext = (finalDelta < -threshold || isFlickNext) && currentPage < total - 1
        let shouldPrev = (finalDelta > threshold || isFlickPrev) && currentPage > 0

        if shouldNext {
            currentPage += 1
            GridMotionStore.shared.setPageTransitionOffset(pageWidth + finalDelta)
        } else if shouldPrev {
            currentPage -= 1
            GridMotionStore.shared.setPageTransitionOffset(-pageWidth + finalDelta)
        } else {
            GridMotionStore.shared.resetOffset(animated: true)
        }
    }

    public func moveItem(from sourceId: String, to targetId: String) {
        guard sourceId != targetId else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSwapTime) > 0.22 else { return }
        guard let fromIndex = items.firstIndex(where: { $0.id == sourceId }),
              let toIndex = items.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        lastSwapTime = now
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            let moved = items.remove(at: fromIndex)
            items.insert(moved, at: toIndex)
        }
    }

    public func mergeIntoFolder(sourceId: String, targetId: String) {
        guard sourceId != targetId else { return }
        guard let sourceIndex = items.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = items.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        let sourceItem = items[sourceIndex]
        let targetItem = items[targetIndex]

        switch (sourceItem, targetItem) {
        case (.app(let sApp), .app(let tApp)):
            // Create a brand new folder containing both apps
            let folderName = (tApp.category?.components(separatedBy: ".").last?.capitalized) ?? "Folder"
            let newFolder = LaunchpadFolder(name: folderName, apps: [tApp, sApp])

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if sourceIndex < targetIndex {
                    items.remove(at: sourceIndex)
                    let newTargetIndex = targetIndex - 1
                    items[newTargetIndex] = .folder(newFolder)
                } else {
                    items.remove(at: sourceIndex)
                    items[targetIndex] = .folder(newFolder)
                }
            }
            saveLayout()

        case (.app(let sApp), .folder(var targetFolder)):
            // Add app into existing folder
            if !targetFolder.apps.contains(where: { $0.id == sApp.id }) {
                targetFolder.apps.append(sApp)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if sourceIndex < targetIndex {
                        items.remove(at: sourceIndex)
                        let newTargetIndex = targetIndex - 1
                        items[newTargetIndex] = .folder(targetFolder)
                    } else {
                        items.remove(at: sourceIndex)
                        items[targetIndex] = .folder(targetFolder)
                    }
                }
                saveLayout()
            }

        default:
            break
        }
    }

    /// Removes an app from a folder and places it onto the main screen.
    /// Dissolves and deletes the folder if 1 or 0 apps remain.
    public func removeAppFromFolder(app: AppItem, folderId: UUID) {
        guard let folderIndex = items.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderId }
            return false
        }) else { return }

        guard case .folder(var currentFolder) = items[folderIndex] else { return }
        currentFolder.apps.removeAll(where: { $0.id == app.id })

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            if currentFolder.apps.isEmpty {
                // Delete empty folder and insert dragged app into items
                items.remove(at: folderIndex)
                items.insert(.app(app), at: folderIndex)
                activeFolder = nil
            } else if currentFolder.apps.count == 1 {
                // Dissolve folder: extract the remaining app and this app
                let remainingApp = currentFolder.apps[0]
                items.remove(at: folderIndex)
                items.insert(.app(remainingApp), at: folderIndex)
                items.insert(.app(app), at: min(folderIndex + 1, items.count))
                activeFolder = nil
            } else {
                // Folder still has 2 or more apps: keep folder updated
                items[folderIndex] = .folder(currentFolder)
                items.insert(.app(app), at: min(folderIndex + 1, items.count))
                activeFolder = currentFolder
            }
        }
        saveLayout()
    }

    /// Updates a folder's name and saves to persistent layout
    public func updateFolderName(folderId: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let folderIndex = items.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderId }
            return false
        }) else { return }

        guard case .folder(var currentFolder) = items[folderIndex] else { return }
        currentFolder.name = trimmed
        items[folderIndex] = .folder(currentFolder)

        if activeFolder?.id == folderId {
            activeFolder = currentFolder
        }

        saveLayout()
        print("[LaunchpadStore] Folder \(folderId) renamed to '\(trimmed)' and saved to layout.")
    }

    private var lastFolderSwapTime: Date = .distantPast

    /// Reorders an app inside a folder
    public func reorderAppInFolder(folderId: UUID, fromIndex: Int, toIndex: Int) {
        guard let idx = items.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderId }
            return false
        }) else { return }

        guard case .folder(var currentFolder) = items[idx] else { return }
        guard fromIndex < currentFolder.apps.count && toIndex < currentFolder.apps.count && fromIndex != toIndex else { return }

        let now = Date()
        guard now.timeIntervalSince(lastFolderSwapTime) > 0.28 else { return }
        lastFolderSwapTime = now

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            let moved = currentFolder.apps.remove(at: fromIndex)
            currentFolder.apps.insert(moved, at: toIndex)
            items[idx] = .folder(currentFolder)
            activeFolder = currentFolder
        }
        saveLayout()
    }

    public func handleArrowKey(_ direction: Int) {
        guard activeFolder == nil else { return }
        let total = pages.count
        guard total > 1 else { return }

        if direction > 0 && currentPage < total - 1 {
            currentPage += 1
            GridMotionStore.shared.setPageTransitionOffset(pageWidth)
        } else if direction < 0 && currentPage > 0 {
            currentPage -= 1
            GridMotionStore.shared.setPageTransitionOffset(-pageWidth)
        }
    }

    public func goToPage(_ targetPage: Int) {
        guard activeFolder == nil else { return }
        guard targetPage != currentPage, targetPage >= 0, targetPage < pages.count else { return }
        let diff = targetPage - currentPage
        currentPage = targetPage
        GridMotionStore.shared.setPageTransitionOffset(CGFloat(diff) * pageWidth)
    }

    public func resetState() {
        self.searchText = ""
        self.activeFolder = nil
        self.draggedItem = nil
        GridMotionStore.shared.dragLocation = .zero
        GridMotionStore.shared.hoverFolderTargetId = nil
        GridMotionStore.shared.dragOffset = 0
    }

    public func hideApp(_ app: AppItem) {
        hiddenBundleIds.insert(app.id)
        saveLayout()
    }

    public func saveLayout() {
        var savedFolders: [SavedFolder] = []
        for item in items {
            if case .folder(let f) = item {
                savedFolders.append(SavedFolder(id: f.id, name: f.name, appIds: f.apps.map(\.id)))
            }
        }

        let config = LaunchpadConfiguration(
            columnsCount: columnsCount,
            rowsCount: rowsCount,
            itemOrder: items.map(\.id),
            folders: savedFolders,
            hiddenAppIds: Array(hiddenBundleIds)
        )
        LayoutPersistenceService.shared.save(config)
    }
}
