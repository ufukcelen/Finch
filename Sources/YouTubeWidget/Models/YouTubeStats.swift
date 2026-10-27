import Foundation

public struct YouTubeStats: Codable, Sendable, Equatable {
    public var channelTitle: String
    public var handle: String
    public var subscriberCount: String
    public var avatarURL: String?
    public var latestShortTitle: String
    public var latestShortViews: String
    public var latestShortThumbnail: String?
    public var latestShortURL: String?
    public var lastUpdated: Date
    public var isConfigured: Bool

    public init(
        channelTitle: String = "YouTube Kanalı",
        handle: String = "@kanal",
        subscriberCount: String = "--",
        avatarURL: String? = nil,
        latestShortTitle: String = "Son Short Henüz Yüklenmedi",
        latestShortViews: String = "--",
        latestShortThumbnail: String? = nil,
        latestShortURL: String? = nil,
        lastUpdated: Date = Date(),
        isConfigured: Bool = false
    ) {
        self.channelTitle = channelTitle
        self.handle = handle
        self.subscriberCount = subscriberCount
        self.avatarURL = avatarURL
        self.latestShortTitle = latestShortTitle
        self.latestShortViews = latestShortViews
        self.latestShortThumbnail = latestShortThumbnail
        self.latestShortURL = latestShortURL
        self.lastUpdated = lastUpdated
        self.isConfigured = isConfigured
    }

    public static let sample = YouTubeStats(
        channelTitle: "Örnek Kanal",
        handle: "@ornekkanal",
        subscriberCount: "125.4K",
        avatarURL: nil,
        latestShortTitle: "Muhteşem Yeni macOS Widget! #shorts",
        latestShortViews: "48.2K izlenme",
        latestShortThumbnail: nil,
        latestShortURL: "https://youtube.com/shorts",
        lastUpdated: Date(),
        isConfigured: true
    )
}
