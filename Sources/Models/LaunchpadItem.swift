import Foundation

public struct LaunchpadFolder: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var apps: [AppItem]

    public init(id: UUID = UUID(), name: String, apps: [AppItem]) {
        self.id = id
        self.name = name
        self.apps = apps
    }
}

public enum LaunchpadItem: Identifiable, Hashable, Sendable {
    case app(AppItem)
    case folder(LaunchpadFolder)

    public var id: String {
        switch self {
        case .app(let app):
            return "app_\(app.id)"
        case .folder(let folder):
            return "folder_\(folder.id.uuidString)"
        }
    }

    public var displayName: String {
        switch self {
        case .app(let app):
            return app.name
        case .folder(let folder):
            return folder.name
        }
    }
}
