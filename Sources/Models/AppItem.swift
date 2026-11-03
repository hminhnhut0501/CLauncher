import Foundation

public struct AppItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String { bundleIdentifier ?? url.path }
    public let name: String
    public let bundleIdentifier: String?
    public let url: URL
    public let isSystemApp: Bool
    public let category: String?
    public let modificationDate: Date?

    public init(
        name: String,
        bundleIdentifier: String?,
        url: URL,
        isSystemApp: Bool,
        category: String? = nil,
        modificationDate: Date? = nil
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.isSystemApp = isSystemApp
        self.category = category
        self.modificationDate = modificationDate
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}
