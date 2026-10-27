import Foundation
import WidgetKit
import AppKit

public struct MultiSocialWidgetConfig: Codable, Sendable {
    public var accounts: [String: SocialAccountStats] // "youtube1", "youtube2", "instagram", "tiktok"
    public var refreshIntervalMinutes: Int
    public var lastSaved: Date

    public init(
        accounts: [String: SocialAccountStats] = [:],
        refreshIntervalMinutes: Int = 360,
        lastSaved: Date = Date()
    ) {
        self.accounts = accounts
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.lastSaved = lastSaved
    }
}

public final class SharedDataManager: @unchecked Sendable {
    public static let shared = SharedDataManager()

    private let mainFileURL: URL
    private let extContainerDir: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.mainFileURL = dir.appendingPathComponent("shared_data.json")

        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let extDir = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true)
        self.extContainerDir = extDir
    }

    public func saveAll(accounts: [String: SocialAccountStats], refreshIntervalMinutes: Int) {
        var configDict: [String: Any] = [:]
        configDict["refreshIntervalMinutes"] = refreshIntervalMinutes
        configDict["lastSaved"] = Date().timeIntervalSince1970

        var accountsDict: [String: Any] = [:]
        for (key, acc) in accounts {
            if let data = try? JSONEncoder().encode(acc),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                accountsDict[key] = json
            }
        }
        configDict["accounts"] = accountsDict

        // Also add root-level legacy keys for the primary youtube1 account for backward compatibility
        if let primary = accounts["youtube1"] ?? accounts.values.first {
            configDict["channelInput"] = primary.handle
            configDict["theme"] = primary.theme
            if let data = try? JSONEncoder().encode(primary),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                configDict["stats"] = json
            }
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: configDict, options: [.prettyPrinted])

            // 1. Write to Main App Application Support
            try data.write(to: mainFileURL, options: .atomic)

            // 2. Write directly to Widget Extension Container
            try? FileManager.default.createDirectory(at: extContainerDir, withIntermediateDirectories: true)
            let extFileURL = extContainerDir.appendingPathComponent("shared_data.json")
            try data.write(to: extFileURL, options: .atomic)

            // 3. Cache images for all slots
            cacheAllImages(accounts: Array(accounts.values))
        } catch {
            print("[SharedDataManager] Error saving multi-widget shared data: \(error)")
        }

        // Invalidate chronod cache so it immediately repaints the native desktop widget
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let chronoPlaceholders = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/SystemData/com.apple.chrono/placeholders", isDirectory: true)
        try? FileManager.default.removeItem(at: chronoPlaceholders)
        let chronoTimelines = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/SystemData/com.apple.chrono/timelines", isDirectory: true)
        try? FileManager.default.removeItem(at: chronoTimelines)

        // Notify WidgetKit
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func save(stats: YouTubeStats, channelInput: String, apiKey: String?, theme: String) {
        let ytAccount = SocialAccountStats(
            slotID: "youtube1",
            platform: .youtube,
            title: stats.channelTitle,
            handle: stats.handle,
            mainStatCount: stats.subscriberCount,
            secondaryTitle: stats.latestShortTitle,
            secondaryValue: stats.latestShortViews,
            avatarURL: stats.avatarURL,
            thumbnailURL: stats.latestShortThumbnail,
            profileURL: stats.handle.starts(with: "@") ? "https://www.youtube.com/\(stats.handle)" : "https://www.youtube.com",
            contentURL: stats.latestShortURL,
            theme: theme,
            lastUpdated: stats.lastUpdated,
            isConfigured: stats.isConfigured
        )

        var existing = loadAccounts() ?? [:]
        existing["youtube1"] = ytAccount
        let interval = loadRefreshInterval()
        saveAll(accounts: existing, refreshIntervalMinutes: interval)
    }

    private func cacheAllImages(accounts: [SocialAccountStats]) {
        Task {
            for acc in accounts {
                let slot = acc.slotID

                // Avatar
                if let avatarStr = acc.avatarURL, let url = URL(string: avatarStr),
                   let (data, _) = try? await URLSession.shared.data(from: url) {
                    let extAvatar = self.extContainerDir.appendingPathComponent("avatar_\(slot).png")
                    try? data.write(to: extAvatar)
                    let mainAvatar = self.mainFileURL.deletingLastPathComponent().appendingPathComponent("avatar_\(slot).png")
                    try? data.write(to: mainAvatar)
                    if slot == "youtube1" {
                        try? data.write(to: self.extContainerDir.appendingPathComponent("avatar.png"))
                    }
                }

                // Thumbnail / Video Cover
                if let thumbStr = acc.thumbnailURL, let url = URL(string: thumbStr),
                   let (data, _) = try? await URLSession.shared.data(from: url) {
                    let extThumb = self.extContainerDir.appendingPathComponent("thumbnail_\(slot).png")
                    try? data.write(to: extThumb)
                    let mainThumb = self.mainFileURL.deletingLastPathComponent().appendingPathComponent("thumbnail_\(slot).png")
                    try? data.write(to: mainThumb)
                    if slot == "youtube1" {
                        try? data.write(to: self.extContainerDir.appendingPathComponent("thumbnail.png"))
                    }
                }
            }

            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    public func loadAccounts() -> [String: SocialAccountStats]? {
        let fileToRead = FileManager.default.fileExists(atPath: mainFileURL.path) ? mainFileURL : extContainerDir.appendingPathComponent("shared_data.json")
        guard let data = try? Data(contentsOf: fileToRead),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accountsDict = json["accounts"] as? [String: [String: Any]] else {
            return nil
        }

        var result: [String: SocialAccountStats] = [:]
        for (key, dict) in accountsDict {
            if let accData = try? JSONSerialization.data(withJSONObject: dict),
               let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: accData) {
                result[key] = acc
            }
        }
        return result
    }

    public func loadRefreshInterval() -> Int {
        let fileToRead = FileManager.default.fileExists(atPath: mainFileURL.path) ? mainFileURL : extContainerDir.appendingPathComponent("shared_data.json")
        if let data = try? Data(contentsOf: fileToRead),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let interval = json["refreshIntervalMinutes"] as? Int, interval > 0 {
            return interval
        }
        return 360 // Default 6 hours
    }
}
