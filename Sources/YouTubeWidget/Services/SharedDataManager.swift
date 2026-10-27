import Foundation
import WidgetKit
import AppKit

public struct SharedWidgetConfig: Codable, Sendable {
    public var channelInput: String
    public var apiKey: String?
    public var stats: YouTubeStats
    public var theme: String // "red", "dark", "glass", "neon"
    public var lastSaved: Date

    public init(
        channelInput: String = "",
        apiKey: String? = nil,
        stats: YouTubeStats = YouTubeStats(),
        theme: String = "red",
        lastSaved: Date = Date()
    ) {
        self.channelInput = channelInput
        self.apiKey = apiKey
        self.stats = stats
        self.theme = theme
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

    public func save(stats: YouTubeStats, channelInput: String, apiKey: String? = nil, theme: String = "red") {
        let config = SharedWidgetConfig(
            channelInput: channelInput,
            apiKey: apiKey,
            stats: stats,
            theme: theme,
            lastSaved: Date()
        )

        do {
            let data = try JSONEncoder().encode(config)

            // 1. Write to Main App Application Support
            try data.write(to: mainFileURL, options: .atomic)

            // 2. Write directly to Widget Extension Container
            try? FileManager.default.createDirectory(at: extContainerDir, withIntermediateDirectories: true)
            let extFileURL = extContainerDir.appendingPathComponent("shared_data.json")
            try data.write(to: extFileURL, options: .atomic)
            
            // 3. Cache avatar and thumbnail locally on disk
            cacheImagesLocally(stats: stats)
        } catch {
            print("[SharedDataManager] Error saving shared data: \(error)")
        }

        // Notify WidgetKit
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func cacheImagesLocally(stats: YouTubeStats) {
        Task {
            if let avatarStr = stats.avatarURL, let url = URL(string: avatarStr),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                let extAvatar = self.extContainerDir.appendingPathComponent("avatar.png")
                try? data.write(to: extAvatar)
                let mainAvatar = self.mainFileURL.deletingLastPathComponent().appendingPathComponent("avatar.png")
                try? data.write(to: mainAvatar)
            }

            if let thumbStr = stats.latestShortThumbnail, let url = URL(string: thumbStr),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                let extThumb = self.extContainerDir.appendingPathComponent("thumbnail.png")
                try? data.write(to: extThumb)
                let mainThumb = self.mainFileURL.deletingLastPathComponent().appendingPathComponent("thumbnail.png")
                try? data.write(to: mainThumb)
            }

            // Invalidate chronod cache so it immediately repaints the native desktop widget
            let userHome = FileManager.default.homeDirectoryForCurrentUser
            let chronoPlaceholders = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/SystemData/com.apple.chrono/placeholders", isDirectory: true)
            try? FileManager.default.removeItem(at: chronoPlaceholders)

            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    public func load() -> SharedWidgetConfig? {
        if let data = try? Data(contentsOf: mainFileURL),
           let config = try? JSONDecoder().decode(SharedWidgetConfig.self, from: data) {
            return config
        }
        return nil
    }
}
