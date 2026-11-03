import AppKit
import SwiftUI

@MainActor
public final class ScrollEventCoordinator: ObservableObject {
    public static let shared = ScrollEventCoordinator()

    public var isFolderActive: Bool = false

    // Folder callbacks
    public var onFolderScrollDelta: ((CGFloat) -> Void)?
    public var onFolderScrollEnded: ((CGFloat, CGFloat) -> Void)?
    public var onFolderArrowKey: ((Int) -> Void)?

    private init() {}
}
