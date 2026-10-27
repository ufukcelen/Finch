import Foundation
import WidgetKit

public struct SharedWidgetConfig: Codable, Sendable {
    public var channelInput: String
    public var apiKey: String?
    public var stats: YouTubeStats
    public var widgetSize: String // "small" or "medium"
    public var lastSaved: Date

    public init(
        channelInput: String = "",
        apiKey: String? = nil,
        stats: YouTubeStats = YouTubeStats(),
        widgetSize: String = "medium",
        lastSaved: Date = Date()
    ) {
        self.channelInput = channelInput
        self.apiKey = apiKey
        self.stats = stats
        self.widgetSize = widgetSize
        self.lastSaved = lastSaved
    }
}

public final class SharedDataManager: @unchecked Sendable {
    public static let shared = SharedDataManager()

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("shared_data.json")
    }

    public func save(stats: YouTubeStats, channelInput: String, apiKey: String? = nil, widgetSize: String = "medium") {
        let config = SharedWidgetConfig(
            channelInput: channelInput,
            apiKey: apiKey,
            stats: stats,
            widgetSize: widgetSize,
            lastSaved: Date()
        )

        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[SharedDataManager] Error saving shared data: \(error)")
        }

        // Also save to shared UserDefaults if available
        if let sharedDefaults = UserDefaults(suiteName: "group.com.ufukcelen.youtubewidget") {
            if let data = try? JSONEncoder().encode(config) {
                sharedDefaults.set(data, forKey: "SharedConfig")
            }
        }

        // Notify WidgetKit to reload desktop & notification center widgets
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func load() -> SharedWidgetConfig? {
        // Try reading from file first
        if let data = try? Data(contentsOf: fileURL),
           let config = try? JSONDecoder().decode(SharedWidgetConfig.self, from: data) {
            return config
        }

        // Fallback to shared UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.ufukcelen.youtubewidget"),
           let data = sharedDefaults.data(forKey: "SharedConfig"),
           let config = try? JSONDecoder().decode(SharedWidgetConfig.self, from: data) {
            return config
        }

        return nil
    }
}
