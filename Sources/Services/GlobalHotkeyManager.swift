import Foundation
import Carbon
import AppKit

public final class GlobalHotkeyManager: @unchecked Sendable {
    public static let shared = GlobalHotkeyManager()

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var callbacks: [UInt32: @Sendable () -> Void] = [:]
    private var nextHotKeyId: UInt32 = 1

    private init() {}

    deinit {
        unregisterAll()
    }

    /// Register a global hotkey using Carbon Events (Zero permission prompt required for standard shortcuts)
    @discardableResult
    public func register(
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping @Sendable () -> Void
    ) -> UInt32? {
        installHandlerIfNeeded()

        let hotKeyId = nextHotKeyId
        nextHotKeyId += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x5441484F), id: hotKeyId) // "TAHO"
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            print("[GlobalHotkey] Failed to register hotkey code: \(keyCode)")
            return nil
        }

        hotKeyRefs.append(ref)
        callbacks[hotKeyId] = action
        return hotKeyId
    }

    public func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        callbacks.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                GlobalHotkeyManager.shared.handleHotKey(id: hotKeyID.id)
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func handleHotKey(id: UInt32) {
        if let callback = callbacks[id] {
            DispatchQueue.main.async {
                callback()
            }
        }
    }
}
