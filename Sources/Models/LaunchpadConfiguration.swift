import Foundation

public struct SavedFolder: Codable, Sendable {
    public let id: UUID
    public var name: String
    public var appIds: [String]

    public init(id: UUID = UUID(), name: String, appIds: [String]) {
        self.id = id
        self.name = name
        self.appIds = appIds
    }
}

public struct LaunchpadConfiguration: Codable, Sendable {
    public var columnsCount: Int
    public var rowsCount: Int
    public var itemOrder: [String] // List of appIds or "folder_<UUID>"
    public var folders: [SavedFolder]
    public var hiddenAppIds: [String]

    public init(
        columnsCount: Int = 7,
        rowsCount: Int = 5,
        itemOrder: [String] = [],
        folders: [SavedFolder] = [],
        hiddenAppIds: [String] = []
    ) {
        self.columnsCount = columnsCount
        self.rowsCount = rowsCount
        self.itemOrder = itemOrder
        self.folders = folders
        self.hiddenAppIds = hiddenAppIds
    }

    public static let `default` = LaunchpadConfiguration(
        columnsCount: 7,
        rowsCount: 5,
        itemOrder: [],
        folders: [],
        hiddenAppIds: []
    )
}
