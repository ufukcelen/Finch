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

    private let primaryDir: URL
    private let targetDirs: [URL]

    public init() {
        var dirs: [URL] = []

        // 1. App Group container (if configured and valid)
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ufukcelen.youtubewidget") {
            let groupDir = groupURL.appendingPathComponent("Library/Application Support/YouTubeWidget", isDirectory: true)
            try? FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: true)
            dirs.append(groupDir)
        }

        // 2. Standard user Application Support
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let standardDir = appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true)
            try? FileManager.default.createDirectory(at: standardDir, withIntermediateDirectories: true)
            dirs.append(standardDir)
        }

        // 3. Extension Container direct path
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let extDirectDir = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: extDirectDir, withIntermediateDirectories: true)
        if !dirs.contains(where: { $0.path == extDirectDir.path }) {
            dirs.append(extDirectDir)
        }

        // 4. Main App Container direct path
        let appDirectDir = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDirectDir, withIntermediateDirectories: true)
        if !dirs.contains(where: { $0.path == appDirectDir.path }) {
            dirs.append(appDirectDir)
        }

        self.targetDirs = dirs
        self.primaryDir = dirs.first ?? FileManager.default.temporaryDirectory

        DebugLogger.shared.log(.info, tag: "SharedDataManager", message: "Hedef depolama dizinleri (\(dirs.count) adet): \(dirs.map { $0.path }.joined(separator: ", "))")
    }

    public func saveAll(accounts: [String: SocialAccountStats], refreshIntervalMinutes: Int) {
        DebugLogger.shared.log(.info, tag: "SharedDataManager", message: "Veriler diske kaydediliyor... (\(accounts.count) hesap, \(refreshIntervalMinutes) dk)")

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

        // Root-level legacy keys for backward compatibility
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

            for dir in targetDirs {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let fileURL = dir.appendingPathComponent("shared_data.json")
                do {
                    try data.write(to: fileURL, options: .atomic)
                    DebugLogger.shared.log(.debug, tag: "SharedDataManager", message: "Yazıldı: \(fileURL.path)")
                } catch {
                    DebugLogger.shared.log(.warning, tag: "SharedDataManager", message: "Yazılamadı: \(fileURL.path) - \(error.localizedDescription)")
                }
            }

            // Cache images asynchronously
            cacheAllImages(accounts: Array(accounts.values))
        } catch {
            DebugLogger.shared.log(.error, tag: "SharedDataManager", message: "JSON serileştirme hatası: \(error)")
        }

        // Invalidate chronod cache if present
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let chronoPlaceholders = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/SystemData/com.apple.chrono/placeholders", isDirectory: true)
        try? FileManager.default.removeItem(at: chronoPlaceholders)
        let chronoTimelines = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/SystemData/com.apple.chrono/timelines", isDirectory: true)
        try? FileManager.default.removeItem(at: chronoTimelines)

        // Notify WidgetKit
        WidgetCenter.shared.reloadAllTimelines()
        DebugLogger.shared.log(.info, tag: "SharedDataManager", message: "WidgetKit.reloadAllTimelines tetiklendi.")
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
                    for dir in self.targetDirs {
                        let avFile = dir.appendingPathComponent("avatar_\(slot).png")
                        try? data.write(to: avFile)
                        if slot == "youtube1" {
                            let legacyAv = dir.appendingPathComponent("avatar.png")
                            try? data.write(to: legacyAv)
                        }
                    }
                }

                // Thumbnail / Video Cover
                if let thumbStr = acc.thumbnailURL, let url = URL(string: thumbStr),
                   let (data, _) = try? await URLSession.shared.data(from: url) {
                    for dir in self.targetDirs {
                        let thFile = dir.appendingPathComponent("thumbnail_\(slot).png")
                        try? data.write(to: thFile)
                        if slot == "youtube1" {
                            let legacyTh = dir.appendingPathComponent("thumbnail.png")
                            try? data.write(to: legacyTh)
                        }
                    }
                }
            }

            WidgetCenter.shared.reloadAllTimelines()
            DebugLogger.shared.log(.debug, tag: "SharedDataManager", message: "Görseller önbelleklendi ve widget yenilendi.")
        }
    }

    public func loadAccounts() -> [String: SocialAccountStats]? {
        for dir in targetDirs {
            let file = dir.appendingPathComponent("shared_data.json")
            if let data = try? Data(contentsOf: file),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accountsDict = json["accounts"] as? [String: [String: Any]] {

                var result: [String: SocialAccountStats] = [:]
                for (key, dict) in accountsDict {
                    if let accData = try? JSONSerialization.data(withJSONObject: dict),
                       let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: accData) {
                        result[key] = acc
                    }
                }
                if !result.isEmpty {
                    return result
                }
            }
        }
        return nil
    }

    public func loadRefreshInterval() -> Int {
        for dir in targetDirs {
            let file = dir.appendingPathComponent("shared_data.json")
            if let data = try? Data(contentsOf: file),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let interval = json["refreshIntervalMinutes"] as? Int, interval > 0 {
                return interval
            }
        }
        return 360 // Default 6 hours
    }

    public func getStorageDiagnostics() -> [(path: String, exists: Bool, sizeBytes: Int)] {
        return targetDirs.map { dir in
            let file = dir.appendingPathComponent("shared_data.json")
            let exists = FileManager.default.fileExists(atPath: file.path)
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return (path: file.path, exists: exists, sizeBytes: size)
        }
    }
}
