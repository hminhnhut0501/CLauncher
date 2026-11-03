import Foundation

public final class LayoutPersistenceService: @unchecked Sendable {
    public static let shared = LayoutPersistenceService()

    private let fileManager = FileManager.default
    private let configFileURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TahoeLaunchpad", isDirectory: true)

        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.configFileURL = appSupport.appendingPathComponent("config.json")
    }

    /// Load saved configuration, or return default
    public func load() -> LaunchpadConfiguration {
        guard fileManager.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL),
              let config = try? JSONDecoder().decode(LaunchpadConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    /// Save configuration asynchronously with atomic write
    public func save(_ config: LaunchpadConfiguration) {
        Task.detached(priority: .utility) { [configFileURL = self.configFileURL] in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(config) {
                try? data.write(to: configFileURL, options: .atomic)
            }
        }
    }

    /// Reset configuration to clean default state
    public func reset() {
        try? fileManager.removeItem(at: configFileURL)
    }
}
