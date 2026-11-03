import Foundation

public final class SmartSearchEngine: Sendable {
    public static let shared = SmartSearchEngine()

    private init() {}

    // Semantic keyword aliases mapping common search terms (EN & VI) to app concepts
    private static let semanticAliases: [String: [String]] = [
        "browser": ["chrome", "safari", "brave", "opera", "firefox", "edge", "coccoc", "web", "internet"],
        "web": ["chrome", "safari", "brave", "opera", "firefox", "edge", "coccoc"],
        "duyet web": ["chrome", "safari", "brave", "opera", "firefox", "coccoc"],
        "video": ["iina", "vlc", "quicktime", "mov", "mp4", "player", "tv", "media", "videotwin"],
        "phim": ["iina", "vlc", "quicktime", "tv", "videotwin"],
        "music": ["music", "spotify", "apple music", "audio", "sound", "nhac", "bai hat", "midi"],
        "nhac": ["music", "spotify", "apple music", "audio", "sound"],
        "am thanh": ["music", "audio", "sound", "midi"],
        "photo": ["photoshop", "photos", "preview", "image", "capture", "hinh", "anh", "ve", "paint", "artcraft", "pixelmator", "magic"],
        "anh": ["photoshop", "photos", "preview", "image", "capture", "artcraft", "magic"],
        "hinh": ["photoshop", "photos", "preview", "image", "capture"],
        "chat": ["telegram", "messages", "chatgpt", "discord", "slack", "zalo", "tin nhan"],
        "tin nhan": ["telegram", "messages", "chatgpt", "discord", "slack", "zalo"],
        "terminal": ["terminal", "iterm", "cmd", "console", "shell", "bash", "zsh", "command"],
        "shell": ["terminal", "iterm", "console"],
        "cmd": ["terminal", "iterm", "console"],
        "code": ["xcode", "antigravity", "visual studio", "vscode", "sublime", "lap trinh", "dev"],
        "lap trinh": ["xcode", "antigravity", "visual studio", "vscode", "sublime"],
        "dev": ["xcode", "antigravity", "visual studio", "vscode", "sublime", "terminal"],
        "clean": ["cleanmymac", "pearcleaner", "appcleaner", "don dep", "rac"],
        "don dep": ["cleanmymac", "pearcleaner", "appcleaner"],
        "setting": ["system settings", "preferences", "cai dat", "tuy chon"],
        "settings": ["system settings", "preferences", "cai dat", "tuy chon"],
        "cai dat": ["system settings", "preferences"],
        "tuy chon": ["system settings", "preferences"],
        "note": ["notes", "ghi chu", "so tay"],
        "ghi chu": ["notes"],
        "mail": ["mail", "email", "thu dien tu"],
        "email": ["mail", "email"],
        "tai": ["download", "downloader", "transmission", "torrent", "hangcu", "iloader"],
        "download": ["downloader", "transmission", "torrent", "hangcu", "iloader"],
        "tien ich": ["utilities", "utility", "activity monitor", "disk utility", "terminal", "console"],
        "utility": ["utilities", "utility", "activity monitor", "disk utility", "console"]
    ]

    public func normalize(_ string: String) -> String {
        return string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func smartAcronyms(for str: String) -> [String] {
        var results = Set<String>()

        // 1. Full word initials: "Adobe Photoshop" -> "ap"
        let words = str.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let wordInitials = words.compactMap { $0.first?.lowercased() }.joined()
        if !wordInitials.isEmpty { results.insert(wordInitials) }

        // 2. Ignore common vendor prefixes: "Adobe", "Google", "Apple", "Microsoft"
        let vendors = ["adobe", "google", "apple", "microsoft"]
        let nonVendorWords = words.filter { !vendors.contains($0.lowercased()) }
        if !nonVendorWords.isEmpty {
            let nonVendorInitials = nonVendorWords.compactMap { $0.first?.lowercased() }.joined()
            if !nonVendorInitials.isEmpty { results.insert(nonVendorInitials) }

            // CamelCase letters: e.g. "CleanMyMac" -> "cmm", "FaceTime" -> "ft"
            for w in nonVendorWords {
                let uppers = w.filter { $0.isUppercase }.lowercased()
                if uppers.count >= 2 {
                    results.insert(uppers)
                }
            }
        }

        // 3. Pro App standard abbreviations
        let lower = str.lowercased()
        if lower.contains("photoshop") { results.insert("ps") }
        if lower.contains("illustrator") { results.insert("ai") }
        if lower.contains("after effects") { results.insert("ae") }
        if lower.contains("premiere") { results.insert("pr") }
        if lower.contains("lightroom") { results.insert("lr") }
        if lower.contains("visual studio code") { results.insert("vsc"); results.insert("vscode") }
        if lower.contains("activity monitor") { results.insert("am") }
        if lower.contains("terminal") { results.insert("term") }

        return Array(results)
    }

    private func isSubsequence(_ pattern: String, in target: String) -> Bool {
        guard !pattern.isEmpty else { return true }
        var pIdx = pattern.startIndex
        var tIdx = target.startIndex
        while pIdx < pattern.endIndex && tIdx < target.endIndex {
            if pattern[pIdx] == target[tIdx] {
                pIdx = pattern.index(after: pIdx)
            }
            tIdx = target.index(after: tIdx)
        }
        return pIdx == pattern.endIndex
    }

    /// Evaluates match quality between app and query (higher score = more relevant)
    public func matchScore(app: AppItem, query: String) -> Int {
        let normQuery = normalize(query)
        guard !normQuery.isEmpty else { return 0 }

        let normName = normalize(app.name)
        let cleanQueryNoSpaces = normQuery.replacingOccurrences(of: " ", with: "")
        let cleanNameNoSpaces = normName.replacingOccurrences(of: " ", with: "")

        // 1. Exact match (Highest relevance)
        if normName == normQuery || cleanNameNoSpaces == cleanQueryNoSpaces {
            return 1000
        }

        // 2. Name starts with query
        if normName.hasPrefix(normQuery) || cleanNameNoSpaces.hasPrefix(cleanQueryNoSpaces) {
            return 800 - normName.count
        }

        // 3. Word starts with query (e.g. "Chrome" in "Google Chrome")
        let words = normName.split(separator: " ").map(String.init)
        if words.contains(where: { $0.hasPrefix(normQuery) }) {
            return 600
        }

        // 4. Smart Acronym & Shortcut matching (e.g. "gc" -> Google Chrome, "ps" -> Photoshop, "ai" -> Illustrator, "cmm" -> CleanMyMac)
        let acronyms = smartAcronyms(for: app.name)
        if acronyms.contains(where: { $0 == normQuery || $0.hasPrefix(normQuery) }) {
            return 550
        }

        // 5. Name contains substring
        if normName.contains(normQuery) || cleanNameNoSpaces.contains(cleanQueryNoSpaces) {
            return 400
        }

        // 6. Bundle Identifier or Category match
        if let bundleId = app.bundleIdentifier?.lowercased(), bundleId.contains(normQuery) {
            return 250
        }
        if let category = app.category?.lowercased(), category.contains(normQuery) {
            return 200
        }

        // 7. Semantic / Synonym / English-Vietnamese alias match
        for (keyword, targets) in Self.semanticAliases {
            if normQuery == keyword || normQuery.contains(keyword) || keyword.contains(normQuery) {
                for target in targets {
                    if normName.contains(target) || cleanNameNoSpaces.contains(target) {
                        return 180
                    }
                }
            }
        }

        // 8. Fuzzy Subsequence match (e.g. "crm" matches "Chrome", "vsc" matches "Visual Studio Code")
        if normQuery.count >= 2 && isSubsequence(cleanQueryNoSpaces, in: cleanNameNoSpaces) {
            return 100
        }

        return 0
    }

    /// Smart search returning sorted LaunchpadItems based on relevance score
    public func search(query: String, in items: [LaunchpadItem], hiddenIds: Set<String>) -> [LaunchpadItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        var scoredApps: [(item: LaunchpadItem, score: Int)] = []

        for item in items {
            switch item {
            case .app(let app):
                guard !hiddenIds.contains(app.id) else { continue }
                let score = matchScore(app: app, query: trimmed)
                if score > 0 {
                    scoredApps.append((.app(app), score))
                }

            case .folder(let folder):
                let normFolderName = normalize(folder.name)
                let normQuery = normalize(trimmed)
                let folderNameScore = normFolderName.contains(normQuery) ? 350 : 0

                // Search inside folder's children
                var bestChildScore = 0
                var matchingChildren: [(app: AppItem, score: Int)] = []
                for child in folder.apps where !hiddenIds.contains(child.id) {
                    let score = matchScore(app: child, query: trimmed)
                    if score > 0 {
                        bestChildScore = max(bestChildScore, score)
                        matchingChildren.append((child, score))
                    }
                }

                if folderNameScore > 0 {
                    // Match on folder name itself
                    scoredApps.append((.folder(folder), folderNameScore))
                } else if !matchingChildren.isEmpty {
                    // Flatten individual matching child apps directly into search results for quick access
                    for match in matchingChildren {
                        scoredApps.append((.app(match.app), match.score))
                    }
                }
            }
        }

        // Sort by score descending, then alphabetically by name
        return scoredApps
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.item.displayName.localizedStandardCompare($1.item.displayName) == .orderedAscending
            }
            .map(\.item)
    }
}
