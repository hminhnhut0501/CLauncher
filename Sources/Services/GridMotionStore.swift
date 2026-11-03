import Foundation
import SwiftUI
import AppKit

/// High-Performance 120Hz Motion & Interaction Coordinator
/// Isolates high-frequency interactive states (scroll deltas, mouse drag locations)
/// from structural data models, preventing expensive whole-tree SwiftUI view body re-evaluations.
@MainActor
public final class GridMotionStore: ObservableObject {
    public static let shared = GridMotionStore()

    /// Horizontal offset during interactive swipe/scroll (measured in points)
    @Published public var dragOffset: CGFloat = 0

    /// Real-time mouse cursor position during icon drag
    @Published public var dragLocation: CGPoint = .zero

    /// Currently hovered folder/app target ID for merge highlighting
    @Published public var hoverFolderTargetId: String? = nil

    private init() {}

    /// Applies 120Hz fluid trackpad/wheel deltas with edge resistance
    public func updateScrollDelta(_ delta: CGFloat, totalPages: Int, currentPage: Int) {
        guard totalPages > 1 else { return }

        let atStart = currentPage == 0 && delta > 0
        let atEnd = currentPage >= totalPages - 1 && delta < 0
        let resistance: CGFloat = (atStart || atEnd) ? 0.28 : 1.0

        self.dragOffset = delta * resistance
    }

    /// Resets the scroll offset back to 0 with Apple-calibrated fluid spring
    public func resetOffset(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                self.dragOffset = 0
            }
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    completion()
                }
            }
        } else {
            self.dragOffset = 0
            completion?()
        }
    }

    /// Sets up interactive page slide transition
    public func setPageTransitionOffset(_ offset: CGFloat) {
        self.dragOffset = offset
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            self.dragOffset = 0
        }
    }
}
