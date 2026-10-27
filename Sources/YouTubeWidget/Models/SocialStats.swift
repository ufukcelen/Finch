import Foundation

public enum SocialPlatform: String, Codable, CaseIterable, Sendable {
    case youtube = "youtube"
    case instagram = "instagram"
    case tiktok = "tiktok"

    public var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        }
    }

    public var iconName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        }
    }

    public var brandColorHex: String {
        switch self {
        case .youtube: return "#FF0000"
        case .instagram: return "#E1306C"
        case .tiktok: return "#00F2FE"
        }
    }

    public var statTitle: String {
        switch self {
        case .youtube: return "ABONE SAYISI"
        case .instagram: return "TAKİPÇİ SAYISI"
        case .tiktok: return "TAKİPÇİ SAYISI"
        }
    }

    public var secondaryTitle: String {
        switch self {
        case .youtube: return "SON SHORTS"
        case .instagram: return "GÖNDERİLER"
        case .tiktok: return "BEĞENİLER"
        }
    }
}

public struct SocialAccountStats: Codable, Sendable, Equatable {
    public var slotID: String // "youtube1", "youtube2", "instagram", "tiktok"
    public var platform: SocialPlatform
    public var title: String
    public var handle: String
    public var mainStatCount: String // e.g. "2,76 B abone", "686M", "96.5m"
    public var secondaryTitle: String // e.g. Shorts title, "1,011 Gönderi", "466.1m Beğeni"
    public var secondaryValue: String // e.g. "1 B izlenme"
    public var avatarURL: String?
    public var thumbnailURL: String?
    public var profileURL: String
    public var contentURL: String?
    public var theme: String // "red", "dark", "glass", "neon", "purple"
    public var lastUpdated: Date
    public var isConfigured: Bool

    public init(
        slotID: String,
        platform: SocialPlatform = .youtube,
        title: String = "",
        handle: String = "",
        mainStatCount: String = "--",
        secondaryTitle: String = "",
        secondaryValue: String = "--",
        avatarURL: String? = nil,
        thumbnailURL: String? = nil,
        profileURL: String = "",
        contentURL: String? = nil,
        theme: String = "red",
        lastUpdated: Date = Date(),
        isConfigured: Bool = false
    ) {
        self.slotID = slotID
        self.platform = platform
        self.title = title
        self.handle = handle
        self.mainStatCount = mainStatCount
        self.secondaryTitle = secondaryTitle
        self.secondaryValue = secondaryValue
        self.avatarURL = avatarURL
        self.thumbnailURL = thumbnailURL
        self.profileURL = profileURL
        self.contentURL = contentURL
        self.theme = theme
        self.lastUpdated = lastUpdated
        self.isConfigured = isConfigured
    }

    public static func defaultSample(for slotID: String, platform: SocialPlatform) -> SocialAccountStats {
        switch platform {
        case .youtube:
            return SocialAccountStats(
                slotID: slotID,
                platform: .youtube,
                title: "YouTube Kanalı",
                handle: "@kanal_ayarla",
                mainStatCount: "--",
                secondaryTitle: "Ayarlardan kanalınızı girin",
                secondaryValue: "--",
                profileURL: "https://www.youtube.com",
                theme: "red"
            )
        case .instagram:
            return SocialAccountStats(
                slotID: slotID,
                platform: .instagram,
                title: "Instagram Profili",
                handle: "@kullanici_ayarla",
                mainStatCount: "--",
                secondaryTitle: "Gönderi verisi yok",
                secondaryValue: "--",
                profileURL: "https://www.instagram.com",
                theme: "purple"
            )
        case .tiktok:
            return SocialAccountStats(
                slotID: slotID,
                platform: .tiktok,
                title: "TikTok Profili",
                handle: "@kullanici_ayarla",
                mainStatCount: "--",
                secondaryTitle: "Beğeni verisi yok",
                secondaryValue: "--",
                profileURL: "https://www.tiktok.com",
                theme: "neon"
            )
        }
    }
}
