import WidgetKit
import SwiftUI
import AppKit
import AppIntents

// MARK: - Timeline Entry
struct SocialTimelineEntry: TimelineEntry {
    let date: Date
    let stats: SocialAccountStats
    let avatarImage: NSImage?
    let thumbnailImage: NSImage?
}

// MARK: - AppIntents Shared Enums
@available(macOS 14.0, *)
public enum WidgetTheme: String, AppEnum, Sendable {
    case red = "red"
    case dark = "dark"
    case glass = "glass"
    case neon = "neon"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Görünüm Teması"
    public static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .red: "🔴 Canlı Kırmızı",
        .dark: "⬛️ Koyu Titanyum",
        .glass: "🪟 Buzlu Cam",
        .neon: "🟣 Siber Mor"
    ]
}

@available(macOS 14.0, *)
public enum WidgetRefreshInterval: Int, AppEnum, Sendable {
    case twoHours = 2
    case sixHours = 6
    case twelveHours = 12
    case twentyFourHours = 24

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Yenileme Sıklığı"
    public static var caseDisplayRepresentations: [WidgetRefreshInterval: DisplayRepresentation] = [
        .twoHours: "2 Saat",
        .sixHours: "6 Saat (Önerilen)",
        .twelveHours: "12 Saat",
        .twentyFourHours: "24 Saat"
    ]
}

// MARK: - 1. YouTube Intent (Per-Widget Configuration on macOS Desktop)
@available(macOS 14.0, *)
public struct YouTubeConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "YouTube Ayarları"
    public static var description = IntentDescription("Masaüstündeki bu widget için YouTube kanalını, temasını ve güncelleme sıklığını belirleyin.")

    @Parameter(title: "Kanal Adı (@kanal)", default: "@RadioMocas")
    public var channel: String

    @Parameter(title: "Görünüm Teması", default: .red)
    public var theme: WidgetTheme

    @Parameter(title: "Yenileme Sıklığı", default: .sixHours)
    public var refreshInterval: WidgetRefreshInterval

    public init() {}

    public init(channel: String = "@RadioMocas", theme: WidgetTheme = .red, refreshInterval: WidgetRefreshInterval = .sixHours) {
        self.channel = channel
        self.theme = theme
        self.refreshInterval = refreshInterval
    }
}

// MARK: - 2. Instagram Intent (Per-Widget Configuration on macOS Desktop)
@available(macOS 14.0, *)
public struct InstagramConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Instagram Ayarları"
    public static var description = IntentDescription("Masaüstündeki bu widget için Instagram hesabını, temasını ve güncelleme sıklığını belirleyin.")

    @Parameter(title: "Kullanıcı Adı (@kullanici)", default: "@uykusuztosba")
    public var username: String

    @Parameter(title: "Görünüm Teması", default: .neon)
    public var theme: WidgetTheme

    @Parameter(title: "Yenileme Sıklığı", default: .sixHours)
    public var refreshInterval: WidgetRefreshInterval

    public init() {}

    public init(username: String = "@uykusuztosba", theme: WidgetTheme = .neon, refreshInterval: WidgetRefreshInterval = .sixHours) {
        self.username = username
        self.theme = theme
        self.refreshInterval = refreshInterval
    }
}

// MARK: - 3. TikTok Intent (Per-Widget Configuration on macOS Desktop)
@available(macOS 14.0, *)
public struct TikTokConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "TikTok Ayarları"
    public static var description = IntentDescription("Masaüstündeki bu widget için TikTok hesabını, temasını ve güncelleme sıklığını belirleyin.")

    @Parameter(title: "Kullanıcı Adı (@kullanici)", default: "@uykusuztosba")
    public var username: String

    @Parameter(title: "Görünüm Teması", default: .dark)
    public var theme: WidgetTheme

    @Parameter(title: "Yenileme Sıklığı", default: .sixHours)
    public var refreshInterval: WidgetRefreshInterval

    public init() {}

    public init(username: String = "@uykusuztosba", theme: WidgetTheme = .dark, refreshInterval: WidgetRefreshInterval = .sixHours) {
        self.username = username
        self.theme = theme
        self.refreshInterval = refreshInterval
    }
}

// MARK: - Data Loader & Cache Engine
enum SocialDataLoader {
    static func containerURL() -> URL {
        var candidates: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ufukcelen.youtubewidget") {
            candidates.append(groupURL.appendingPathComponent("Library/Application Support/YouTubeWidget", isDirectory: true))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true))
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true))
        }
        candidates.append(home.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget/Data/Library/Application Support/YouTubeWidget", isDirectory: true))

        for dir in candidates {
            let file = dir.appendingPathComponent("shared_data.json")
            if FileManager.default.fileExists(atPath: file.path) {
                return dir
            }
        }
        return candidates.first ?? FileManager.default.temporaryDirectory
    }

    static func safeKey(_ str: String) -> String {
        return str.replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    static func loadFromCache(platform: SocialPlatform, handle: String) -> SocialAccountStats? {
        let dir = containerURL()
        let file = dir.appendingPathComponent("shared_data.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accountsDict = json["accounts"] as? [String: [String: Any]] else {
            return nil
        }

        let targetClean = safeKey(handle)

        // 1. Direct handle match only - never fall back to global platform slot!
        for (_, val) in accountsDict {
            if let accData = try? JSONSerialization.data(withJSONObject: val),
               let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: accData) {
                if safeKey(acc.handle) == targetClean && acc.platform == platform {
                    return acc
                }
            }
        }

        return nil
    }

    static func saveToCache(stats: SocialAccountStats) {
        let dir = containerURL()
        let file = dir.appendingPathComponent("shared_data.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var dict: [String: Any] = [:]
        if let data = try? Data(contentsOf: file),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = existing
        }

        var accounts = dict["accounts"] as? [String: [String: Any]] ?? [:]
        if let encoded = try? JSONEncoder().encode(stats),
           let statDict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
            // Save ONLY under the specific handle so channels never overwrite each other!
            accounts[safeKey(stats.handle)] = statDict
        }
        dict["accounts"] = accounts
        dict["lastSaved"] = Date().timeIntervalSince1970

        if let finalData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            try? finalData.write(to: file)
        }
    }

    static func loadImage(urlStr: String?, key: String) async -> NSImage? {
        guard let urlStr = urlStr, !urlStr.isEmpty else { return nil }
        let dir = containerURL()
        let file = dir.appendingPathComponent(key)

        // 1. Local disk cache
        if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
            return img
        }

        // 2. Live fetch
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = NSImage(data: data) {
                try? data.write(to: file)
                return img
            }
        } catch {
            return nil
        }
        return nil
    }

    static func load(platform: SocialPlatform, rawQuery: String, theme: String) async -> (SocialAccountStats, NSImage?, NSImage?) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultHandle: String
        switch platform {
        case .youtube: defaultHandle = "@RadioMocas"
        case .instagram: defaultHandle = "@uykusuztosba"
        case .tiktok: defaultHandle = "@uykusuztosba"
        }
        let handle = trimmed.isEmpty ? defaultHandle : trimmed

        // 1. Try local cache for this specific handle
        var stats = loadFromCache(platform: platform, handle: handle)

        // 2. Live fetch if no cache or older than 30 minutes
        let isStale = stats == nil || Date().timeIntervalSince(stats?.lastUpdated ?? .distantPast) > 1800
        if isStale {
            if let live = try? await SocialService.shared.fetchStats(slotID: safeKey(handle), platform: platform, input: handle, theme: theme) {
                stats = live
                saveToCache(stats: live)
            }
        }

        // 3. If stats is nil (e.g. invalid handle, typo like @raidomocas, or offline), build informative fallback
        var finalStats: SocialAccountStats
        if let s = stats {
            finalStats = s
        } else {
            finalStats = SocialAccountStats.defaultSample(for: handle, platform: platform)
            finalStats.handle = handle.hasPrefix("@") ? handle : "@\(handle)"
            finalStats.title = handle.replacingOccurrences(of: "@", with: "")
            finalStats.mainStatCount = "Bulunamadı"
            finalStats.secondaryTitle = "Kanal adını kontrol edin"
            finalStats.secondaryValue = "--"
        }

        finalStats.theme = theme

        let keyHandle = safeKey(finalStats.handle)
        let avatar = await loadImage(urlStr: finalStats.avatarURL, key: "\(platform.rawValue)_\(keyHandle)_avatar.jpg")
        let thumb = await loadImage(urlStr: finalStats.thumbnailURL, key: "\(platform.rawValue)_\(keyHandle)_thumb.jpg")

        return (finalStats, avatar, thumb)
    }
}

// MARK: - 1. YouTube Timeline Provider
@available(macOS 14.0, *)
struct YouTubeAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialTimelineEntry {
        let stats = SocialAccountStats.defaultSample(for: "youtube", platform: .youtube)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: nil, thumbnailImage: nil)
    }

    func snapshot(for configuration: YouTubeConfigurationIntent, in context: Context) async -> SocialTimelineEntry {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .youtube, rawQuery: configuration.channel, theme: configuration.theme.rawValue)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)
    }

    func timeline(for configuration: YouTubeConfigurationIntent, in context: Context) async -> Timeline<SocialTimelineEntry> {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .youtube, rawQuery: configuration.channel, theme: configuration.theme.rawValue)
        let entry = SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)

        let intervalHours = configuration.refreshInterval.rawValue
        let nextDate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalHours * 3600))
        return Timeline(entries: [entry], policy: .after(nextDate))
    }
}

// MARK: - 2. Instagram Timeline Provider
@available(macOS 14.0, *)
struct InstagramAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialTimelineEntry {
        let stats = SocialAccountStats.defaultSample(for: "instagram", platform: .instagram)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: nil, thumbnailImage: nil)
    }

    func snapshot(for configuration: InstagramConfigurationIntent, in context: Context) async -> SocialTimelineEntry {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .instagram, rawQuery: configuration.username, theme: configuration.theme.rawValue)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)
    }

    func timeline(for configuration: InstagramConfigurationIntent, in context: Context) async -> Timeline<SocialTimelineEntry> {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .instagram, rawQuery: configuration.username, theme: configuration.theme.rawValue)
        let entry = SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)

        let intervalHours = configuration.refreshInterval.rawValue
        let nextDate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalHours * 3600))
        return Timeline(entries: [entry], policy: .after(nextDate))
    }
}

// MARK: - 3. TikTok Timeline Provider
@available(macOS 14.0, *)
struct TikTokAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialTimelineEntry {
        let stats = SocialAccountStats.defaultSample(for: "tiktok", platform: .tiktok)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: nil, thumbnailImage: nil)
    }

    func snapshot(for configuration: TikTokConfigurationIntent, in context: Context) async -> SocialTimelineEntry {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .tiktok, rawQuery: configuration.username, theme: configuration.theme.rawValue)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)
    }

    func timeline(for configuration: TikTokConfigurationIntent, in context: Context) async -> Timeline<SocialTimelineEntry> {
        let (stats, avatar, thumb) = await SocialDataLoader.load(platform: .tiktok, rawQuery: configuration.username, theme: configuration.theme.rawValue)
        let entry = SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)

        let intervalHours = configuration.refreshInterval.rawValue
        let nextDate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalHours * 3600))
        return Timeline(entries: [entry], policy: .after(nextDate))
    }
}

// MARK: - Widget Views
struct SocialWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: SocialTimelineEntry

    var body: some View {
        if #available(macOS 14.0, *) {
            contentView
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        } else {
            contentView
                .background(widgetBackground)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        default:
            mediumWidgetView
        }
    }

    // MARK: - SystemSmall View (Clean widgetURL with no child Links)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Avatar + Title + Platform Badge
            HStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    if let img = entry.avatarImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }

                    Circle()
                        .fill(Color(hex: entry.stats.platform.brandColorHex))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Image(systemName: entry.stats.platform.iconName)
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.stats.title.isEmpty ? entry.stats.platform.displayName : entry.stats.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(entry.stats.handle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            // Main Stat Count (Abone / Takipçi)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.stats.displayStatNumber)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Circle()
                        .fill(Color(hex: entry.stats.platform.brandColorHex))
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: entry.stats.platform.brandColorHex).opacity(0.6), lineWidth: 1.5)
                                .scaleEffect(1.6)
                        )
                }

                Text(entry.stats.platform.statTitle)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(1.0)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: entry.stats.platform.iconName)
                        .font(.system(size: 8))
                    Text(entry.stats.platform.displayName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: entry.stats.platform.brandColorHex))

                Spacer()

                Text("Canlı")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(13)
        .widgetURL(entry.stats.validProfileURL)
    }

    // MARK: - SystemMedium View
    private var mediumWidgetView: some View {
        HStack(spacing: 12) {
            // Left Column: Account & Stat Count
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Link(destination: entry.stats.validProfileURL) {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = entry.avatarImage {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.primary.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }

                            Circle()
                                .fill(Color(hex: entry.stats.platform.brandColorHex))
                                .frame(width: 11, height: 11)
                                .overlay(
                                    Image(systemName: entry.stats.platform.iconName)
                                        .font(.system(size: 5, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    Link(destination: entry.stats.validProfileURL) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.stats.title.isEmpty ? entry.stats.platform.displayName : entry.stats.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(entry.stats.handle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    // Platform Logo / Settings link
                    Link(destination: URL(string: "youtubewidget://settings?platform=\(entry.stats.platform.rawValue)")!) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                // Main Metric
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.stats.displayStatNumber)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Circle()
                            .fill(Color(hex: entry.stats.platform.brandColorHex))
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: entry.stats.platform.brandColorHex).opacity(0.6), lineWidth: 1.5)
                                    .scaleEffect(1.6)
                            )
                    }

                    Text(entry.stats.platform.statTitle)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.0)
                }

                Spacer(minLength: 0)

                // Footer
                HStack(spacing: 4) {
                    Image(systemName: entry.stats.platform.iconName)
                        .font(.system(size: 9))
                    Text(entry.stats.platform.displayName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: entry.stats.platform.brandColorHex))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color.white.opacity(0.12))

            // Right Column: Latest Content or Secondary Metric
            VStack(alignment: .leading, spacing: 6) {
                if let thumb = entry.thumbnailImage {
                    Link(destination: entry.stats.validContentURL) {
                        ZStack(alignment: .bottomLeading) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 78)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.75)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    .cornerRadius(8)
                                )

                            if !entry.stats.secondaryValue.isEmpty && entry.stats.secondaryValue != "--" {
                                HStack(spacing: 3) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 8))
                                    Text(entry.stats.secondaryValue)
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(4)
                                .padding(5)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if !entry.stats.secondaryTitle.isEmpty {
                        Text(entry.stats.secondaryTitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                } else {
                    // Secondary Metric Card when no thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.stats.secondaryTitle.isEmpty ? entry.stats.platform.secondaryTitle : entry.stats.secondaryTitle)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)

                        Text(entry.stats.secondaryValue.isEmpty ? "--" : entry.stats.secondaryValue)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)

                    Link(destination: entry.stats.validProfileURL) {
                        HStack(spacing: 4) {
                            Text("Profile Git")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
    }

    @ViewBuilder
    private var widgetBackground: some View {
        switch entry.stats.theme {
        case "dark":
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.14)
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.black.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case "glass":
            ZStack {
                Color.black.opacity(0.55)
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case "neon":
            ZStack {
                Color(red: 0.08, green: 0.05, blue: 0.15)
                LinearGradient(
                    colors: [Color(red: 0.85, green: 0.1, blue: 0.5).opacity(0.45), Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        default:
            // "red"
            ZStack {
                Color(red: 0.14, green: 0.04, blue: 0.04)
                LinearGradient(
                    colors: [Color(red: 0.85, green: 0.1, blue: 0.1).opacity(0.50), Color.black.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// Color Hex Helper
extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleanHex.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - 3 Independent AppIntent-Configurable Widgets
@available(macOS 14.0, *)
struct YouTubeWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.intent.youtube"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: YouTubeConfigurationIntent.self,
            provider: YouTubeAppIntentTimelineProvider()
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube")
        .description("YouTube abone sayınızı ve son Shorts videonuzu takip edin. Sağ tıkla kanalınızı belirleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@available(macOS 14.0, *)
struct InstagramWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.intent.instagram"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: InstagramConfigurationIntent.self,
            provider: InstagramAppIntentTimelineProvider()
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Instagram")
        .description("Instagram takipçi ve gönderi sayınızı takip edin. Sağ tıkla kullanıcı adınızı belirleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@available(macOS 14.0, *)
struct TikTokWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.intent.tiktok"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TikTokConfigurationIntent.self,
            provider: TikTokAppIntentTimelineProvider()
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TikTok")
        .description("TikTok takipçi ve beğeni sayınızı takip edin. Sağ tıkla kullanıcı adınızı belirleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Multi-Widget Bundle
@main
struct SocialWidgetBundle: WidgetBundle {
    var body: some Widget {
        YouTubeWidget()
        InstagramWidget()
        TikTokWidget()
    }
}
