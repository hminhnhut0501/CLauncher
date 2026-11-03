import AppKit
import Carbon
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as regular app so it can live in the Dock
        NSApp.setActivationPolicy(.regular)

        // Pre-warm Launchpad window & cache
        LaunchpadWindowController.shared.start()

        // Setup Menu Bar Item
        setupStatusBar()

        // Setup Global Hotkeys (F4 & Option+Space)
        setupGlobalHotkeys()

        // Show Launchpad immediately on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            LaunchpadWindowController.shared.show()
        }

        print("[Launchpad] Launched and visible! Click Dock icon, Menu Bar, or press [Option+Space] / [F4].")
    }

    /// Called whenever the user clicks the app icon in the Dock or Finder
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LaunchpadWindowController.shared.show()
        return false
    }

    private func setupGlobalHotkeys() {
        let hotkeyManager = GlobalHotkeyManager.shared

        hotkeyManager.register(keyCode: 49, modifiers: UInt32(optionKey)) {
            Task { @MainActor in
                LaunchpadWindowController.shared.toggle()
            }
        }

        hotkeyManager.register(keyCode: 118, modifiers: 0) {
            Task { @MainActor in
                LaunchpadWindowController.shared.toggle()
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Launchpad")?.withSymbolConfiguration(config) {
            button.image = image
        } else {
            button.title = "🚀"
        }

        button.target = self
        button.action = #selector(statusBarClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            LaunchpadWindowController.shared.toggle()
            return
        }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Toggle Launchpad (⌥Space / F4)", action: #selector(toggleLaunchpad), keyEquivalent: " "))
            menu.addItem(NSMenuItem(title: "Reload Applications", action: #selector(reloadApplications), keyEquivalent: "r"))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit Launchpad", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            LaunchpadWindowController.shared.toggle()
        }
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Launchpad Preferences"
            window.contentView = NSHostingView(rootView: PreferencesView())
            window.center()
            window.isReleasedWhenClosed = false
            self.preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchpad() {
        LaunchpadWindowController.shared.toggle()
    }

    @objc private func reloadApplications() {
        Task {
            await LaunchpadWindowController.shared.reloadApps(forceRefreshIcons: true)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
