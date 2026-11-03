import AppKit
import SwiftUI

@MainActor
public final class LaunchpadWindowController: NSObject {
    public static let shared = LaunchpadWindowController()

    private var panel: LaunchpadPanel?
    private let scanner = ApplicationScanner()
    private var fileWatcher: FileSystemWatcher?
    private var reloadDebounceTask: Task<Void, Never>?
    private(set) public var isVisible: Bool = false

    private override init() {
        super.init()
    }

    /// Pre-warm window and background scanning on app start
    public func start() {
        setupPanel()
        setupFileWatcher()
        Task {
            await reloadApps()
        }
    }

    public func reloadApps(forceRefreshIcons: Bool = false) async {
        if forceRefreshIcons {
            IconCacheService.shared.clearAllCache()
        }
        let scanned = await scanner.scanAllApplications()
        LaunchpadStore.shared.setApps(scanned)
        IconCacheService.shared.preheat(apps: scanned, limit: 120)
    }

    private func setupPanel() {
        guard panel == nil else { return }

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let newPanel = LaunchpadPanel(contentRect: screenFrame)

        newPanel.onDismiss = { [weak self] in
            self?.hide()
        }

        let rootView = LaunchpadRootView { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.drawsAsynchronously = true
        newPanel.contentView = hostingView

        self.panel = newPanel
    }

    private func setupFileWatcher() {
        fileWatcher = FileSystemWatcher { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.reloadDebounceTask?.cancel()
                self.reloadDebounceTask = Task {
                    // Debounce 1.0s to allow installers or file copying to fully finish
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await self.reloadApps()
                }
            }
        }
        fileWatcher?.start()
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        if panel == nil { setupPanel() }
        guard let panel = self.panel else { return }

        // Match current active screen
        if let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            panel.setFrame(currentScreen.frame, display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        panel.enableProMotion120Hz(duration: 0.6)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
    }

    public func hide() {
        guard let panel = self.panel else { return }
        isVisible = false
        panel.disableProMotion120Hz()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self, !self.isVisible else { return }
            panel.orderOut(nil)
            LaunchpadStore.shared.resetState()
            GridMotionStore.shared.resetOffset(animated: false)
        })
    }
}
