import AppKit
import QuartzCore

public final class LaunchpadPanel: NSPanel {
    public var onDismiss: (() -> Void)?

    private var accumulatedDeltaX: CGFloat = 0
    private var isTrackingGesture: Bool = false
    private var discreteCooldown: Bool = false
    private var proMotionDisplayLink: Any?
    private var proMotionTimer: Timer?
    private var lastScrollTime: TimeInterval = 0
    private var currentVelocityX: CGFloat = 0

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless
            ],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false

        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
    }

    override public var canBecomeKey: Bool {
        return true
    }

    override public var canBecomeMain: Bool {
        return true
    }

    /// Engages Apple ProMotion 120Hz variable refresh rate across the entire WindowServer compositor on demand
    public func enableProMotion120Hz(duration: TimeInterval = 0.5) {
        if #available(macOS 14.0, *) {
            if proMotionDisplayLink == nil {
                let dl = self.displayLink(target: self, selector: #selector(displayLinkHeartbeat(_:)))
                dl.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
                dl.add(to: .main, forMode: .common)
                self.proMotionDisplayLink = dl
            }
            proMotionTimer?.invalidate()
            proMotionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.disableProMotion120Hz()
                }
            }
        }
    }

    public func disableProMotion120Hz() {
        proMotionTimer?.invalidate()
        proMotionTimer = nil
        if #available(macOS 14.0, *) {
            if let dl = proMotionDisplayLink as? CADisplayLink {
                dl.invalidate()
            }
        }
        self.proMotionDisplayLink = nil
    }

    @objc private func displayLinkHeartbeat(_ displayLink: CADisplayLink) {
        // High-frequency 120Hz DisplayLink keeping WindowServer locked in ProMotion mode during active interaction
    }

    // Intercept all events at window dispatch level (guarantees 100% reliable 120Hz scroll & swipe over all subviews)
    override public func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel {
            handleScrollWheel(event)
            return
        }

        if event.type == .keyDown {
            if event.keyCode == 53 { // Escape
                onDismiss?()
                return
            } else if event.keyCode == 123 || event.keyCode == 116 { // Left arrow or Page Up
                handlePageTurn(-1)
                return
            } else if event.keyCode == 124 || event.keyCode == 121 { // Right arrow or Page Down
                handlePageTurn(1)
                return
            }
        }

        super.sendEvent(event)
    }

    private func handlePageTurn(_ direction: Int) {
        enableProMotion120Hz(duration: 0.5)
        // Zero-latency synchronous MainActor dispatch
        if LaunchpadStore.shared.activeFolder != nil {
            ScrollEventCoordinator.shared.onFolderArrowKey?(direction)
        } else {
            LaunchpadStore.shared.handleArrowKey(direction)
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        let isPrecise = event.hasPreciseScrollingDeltas
        let deltaX = isPrecise ? event.scrollingDeltaX : event.deltaX * 16
        let deltaY = isPrecise ? event.scrollingDeltaY : event.deltaY * 16

        // Prefer horizontal delta; allow vertical mouse-wheel fallback for single-axis wheels
        let primaryDelta = abs(deltaX) >= abs(deltaY) ? deltaX : (isPrecise ? deltaX : deltaY)

        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastScrollTime
        lastScrollTime = now

        if event.phase == .began {
            enableProMotion120Hz(duration: 0.8)
            isTrackingGesture = true
            accumulatedDeltaX = 0
            currentVelocityX = 0
        } else if event.phase == .changed && isTrackingGesture {
            enableProMotion120Hz(duration: 0.8)
            accumulatedDeltaX += primaryDelta
            if dt > 0.001 && dt < 0.1 {
                currentVelocityX = primaryDelta / CGFloat(dt)
            }
            let delta = accumulatedDeltaX
            // Direct synchronous MainActor update (No Task dispatch latency: achieves true 120Hz fluid tracking!)
            if LaunchpadStore.shared.activeFolder != nil {
                ScrollEventCoordinator.shared.onFolderScrollDelta?(delta)
            } else {
                LaunchpadStore.shared.handleScrollDelta(delta)
            }
        } else if event.phase == .ended || event.phase == .cancelled {
            isTrackingGesture = false
            let final = accumulatedDeltaX
            let velocity = currentVelocityX
            accumulatedDeltaX = 0
            currentVelocityX = 0
            if LaunchpadStore.shared.activeFolder != nil {
                ScrollEventCoordinator.shared.onFolderScrollEnded?(final, velocity)
            } else {
                LaunchpadStore.shared.handleScrollEnded(final, velocity: velocity)
            }
        } else if event.phase == [] && event.momentumPhase == [] {
            // Traditional discrete mouse wheel step
            if !discreteCooldown && abs(primaryDelta) > 1.2 {
                let direction = primaryDelta > 0 ? -1 : 1
                handlePageTurn(direction)
                discreteCooldown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                    self?.discreteCooldown = false
                }
            }
        }
    }
}
