import WidgetKit
import SwiftUI
import AppKit
import AppIntents

// MARK: - App Intents (Per-Widget Configuration on macOS Desktop)
@available(macOS 14.0, *)
public enum WidgetPlatform: String, AppEnum, Sendable {
    case youtube = "YouTube"
    case instagram = "Instagram"
    case tiktok = "TikTok"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Platform"
    public static var caseDisplayRepresentations: [WidgetPlatform: DisplayRepresentation] = [
        .youtube: "🔴 YouTube",
        .instagram: "📸 Instagram",
        .tiktok: "🎵 TikTok"
    ]

    public func toSocialPlatform() -> SocialPlatform {
        switch self {
        case .youtube: return .youtube
        case .instagram: return .instagram
        case .tiktok: return .tiktok
        }
    }
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
        .neon: "🟣 Siber Mor Neon"
    ]
}

@available(macOS 14.0, *)
public struct SelectAccountIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Sosyal Widget Ayarları"
    public static var description = IntentDescription("Bu widget'ın platformunu, kanalını, temasını ve güncelleme sıklığını belirleyin.")

    @Parameter(title: "Platform", default: .youtube)
    public var platform: WidgetPlatform

    @Parameter(title: "Kanal / Kullanıcı Adı", default: "@barisozcan")
    public var accountHandle: String

    @Parameter(title: "Yenileme Sıklığı", default: .sixHours)
    public var refreshInterval: WidgetRefreshInterval

    @Parameter(title: "Görünüm Teması", default: .red)
    public var theme: WidgetTheme

    public init() {}

    public init(platform: WidgetPlatform, accountHandle: String, refreshInterval: WidgetRefreshInterval = .sixHours, theme: WidgetTheme = .red) {
        self.platform = platform
        self.accountHandle = accountHandle
        self.refreshInterval = refreshInterval
        self.theme = theme
    }
}

// MARK: - Timeline Entry
struct SocialTimelineEntry: TimelineEntry {
    let date: Date
    let stats: SocialAccountStats
    let avatarImage: NSImage?
    let thumbnailImage: NSImage?
}

// MARK: - Timeline Provider (Fetches Independently for Each Desktop Instance)
@available(macOS 14.0, *)
struct SocialAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialTimelineEntry {
        let sample = SocialAccountStats.defaultSample(for: "placeholder", platform: .youtube)
        return SocialTimelineEntry(date: Date(), stats: sample, avatarImage: nil, thumbnailImage: nil)
    }

    func snapshot(for configuration: SelectAccountIntent, in context: Context) async -> SocialTimelineEntry {
        let platform = configuration.platform.toSocialPlatform()
        let handle = configuration.accountHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = configuration.theme.rawValue
        let entry = await getEntry(platform: platform, handle: handle, theme: theme)
        return entry
    }

    func timeline(for configuration: SelectAccountIntent, in context: Context) async -> Timeline<SocialTimelineEntry> {
        let platform = configuration.platform.toSocialPlatform()
        let handle = configuration.accountHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = configuration.theme.rawValue
        let intervalHours = configuration.refreshInterval.rawValue

        let entry = await getEntry(platform: platform, handle: handle, theme: theme)

        // Schedule next refresh strictly according to this widget instance's chosen interval
        let nextDate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalHours * 3600))
        return Timeline(entries: [entry], policy: .after(nextDate))
    }

    private func getEntry(platform: SocialPlatform, handle: String, theme: String) async -> SocialTimelineEntry {
        let cleanHandle = handle.isEmpty ? (platform == .youtube ? "@barisozcan" : (platform == .instagram ? "@instagram" : "@tiktok")) : handle
        let safeKey = "\(platform.rawValue)_\(cleanHandle.replacingOccurrences(of: "@", with: "").replacingOccurrences(of: "/", with: "_"))"

        // 1. Try to fetch live stats directly
        var stats: SocialAccountStats? = nil
        do {
            stats = try await SocialService.shared.fetchStats(
                slotID: safeKey,
                platform: platform,
                input: cleanHandle,
                apiKey: nil,
                theme: theme
            )
        } catch {
            print("[WidgetProvider] Live fetch error for \(safeKey): \(error.localizedDescription)")
        }

        // 2. If live fetch succeeded, cache it locally
        if let live = stats {
            saveCachedStats(live, key: safeKey)
            await cacheImages(stats: live, key: safeKey)
        } else {
            // Fallback to locally cached stats
            stats = loadCachedStats(key: safeKey)
        }

        let finalStats = stats ?? SocialAccountStats.defaultSample(for: safeKey, platform: platform)
        let avatar = loadLocalImage(named: "avatar_\(safeKey).png")
        let thumb = loadLocalImage(named: "thumb_\(safeKey).png")

        return SocialTimelineEntry(
            date: Date(),
            stats: finalStats,
            avatarImage: avatar,
            thumbnailImage: thumb
        )
    }

    // MARK: - Helpers & Caching
    private func containerURL() -> URL {
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let dir = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveCachedStats(_ stats: SocialAccountStats, key: String) {
        let file = containerURL().appendingPathComponent("cache_\(key).json")
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: file)
        }
    }

    private func loadCachedStats(key: String) -> SocialAccountStats? {
        let file = containerURL().appendingPathComponent("cache_\(key).json")
        if let data = try? Data(contentsOf: file),
           let stats = try? JSONDecoder().decode(SocialAccountStats.self, from: data) {
            return stats
        }

        // Fallback: Check shared_data.json from main app if exists
        let sharedFile = containerURL().appendingPathComponent("shared_data.json")
        if let data = try? Data(contentsOf: sharedFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accountsDict = json["accounts"] as? [String: [String: Any]] {
            for (_, accDict) in accountsDict {
                if let accData = try? JSONSerialization.data(withJSONObject: accDict),
                   let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: accData) {
                    if acc.handle.lowercased() == key.lowercased() || key.contains(acc.handle.replacingOccurrences(of: "@", with: "")) {
                        return acc
                    }
                }
            }
        }
        return nil
    }

    private func cacheImages(stats: SocialAccountStats, key: String) async {
        let dir = containerURL()
        if let avURLStr = stats.avatarURL, let url = URL(string: avURLStr) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                let avFile = dir.appendingPathComponent("avatar_\(key).png")
                try? data.write(to: avFile)
            }
        }
        if let thURLStr = stats.thumbnailURL, let url = URL(string: thURLStr) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                let thFile = dir.appendingPathComponent("thumb_\(key).png")
                try? data.write(to: thFile)
            }
        }
    }

    private func loadLocalImage(named: String) -> NSImage? {
        let file = containerURL().appendingPathComponent(named)
        if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
            return img
        }
        return nil
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

    // MARK: - SystemSmall View (Abone / Takipçi Sayısı)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Avatar + Title + Settings Gear Button
            HStack(spacing: 7) {
                // Avatar + Platform icon
                Link(destination: entry.stats.validProfileURL) {
                    ZStack(alignment: .bottomTrailing) {
                        if let img = entry.avatarImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.primary.opacity(0.15))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                )
                        }

                        // Mini platform badge
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
                }
                .buttonStyle(.plain)

                // Title + Handle
                Link(destination: entry.stats.validProfileURL) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.stats.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(entry.stats.handle)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                // ⚙️ Settings Gear Button (Opens helper app directly)
                Link(destination: URL(string: "youtubewidget://settings")!) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.40))
                        )
                }
                .buttonStyle(.plain)
                .help("Widget Ayarları & Test")
            }

            Spacer(minLength: 0)

            // Main Stat Count (Abone / Takipçi)
            Link(destination: entry.stats.validProfileURL) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(entry.stats.mainStatCount)
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
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.0)
                }
            }
            .buttonStyle(.plain)

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
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(13)
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
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
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
                            Text(entry.stats.title)
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

                    // ⚙️ Settings Gear Button
                    Link(destination: URL(string: "youtubewidget://settings")!) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.40))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Widget Ayarları & Test")
                }

                Spacer(minLength: 0)

                Link(destination: entry.stats.validProfileURL) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(entry.stats.mainStatCount)
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Circle()
                                .fill(Color(hex: entry.stats.platform.brandColorHex))
                                .frame(width: 7, height: 7)
                        }

                        Text(entry.stats.platform.statTitle)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1.0)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    Image(systemName: entry.stats.platform.iconName)
                        .font(.system(size: 8))
                    Text(entry.stats.platform.displayName)
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(Color(hex: entry.stats.platform.brandColorHex))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .opacity(0.3)

            // Right Column: Secondary Content / Card
            rightContentCard
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    @ViewBuilder
    private var rightContentCard: some View {
        switch entry.stats.platform {
        case .youtube:
            // YouTube: Latest Shorts Card
            Link(destination: entry.stats.validContentURL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SON SHORTS")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(.red)
                        .tracking(0.8)

                    HStack(spacing: 8) {
                        if let thumb = entry.thumbnailImage {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 60)
                                .cornerRadius(6)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 44, height: 60)
                                .overlay(
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.stats.secondaryTitle.isEmpty ? "Son Short Yüklenmedi" : entry.stats.secondaryTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            HStack(spacing: 3) {
                                Text("🔥")
                                    .font(.system(size: 9))
                                Text(entry.stats.secondaryValue)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                    }
                }
            }
            .buttonStyle(.plain)

        case .instagram:
            // Instagram: Posts & Profile info
            Link(destination: entry.stats.validProfileURL) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GÖNDERİLER")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#E1306C"))
                        .tracking(0.8)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#E1306C"))

                            Text(entry.stats.secondaryValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Spacer(minLength: 0)

                        HStack {
                            Text("Profili Aç")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                }
            }
            .buttonStyle(.plain)

        case .tiktok:
            // TikTok: Likes & Profile info
            Link(destination: entry.stats.validProfileURL) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BEĞENİLER")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#00F2FE"))
                        .tracking(0.8)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.pink)

                            Text(entry.stats.secondaryValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Spacer(minLength: 0)

                        HStack {
                            Text("TikTok'u Aç")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        switch entry.stats.theme {
        case "dark":
            ZStack {
                Color.black.opacity(0.88)
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.black.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case "glass":
            Color.black.opacity(0.2)
        case "neon":
            ZStack {
                Color.black.opacity(0.5)
                LinearGradient(
                    colors: [Color(red: 0.9, green: 0.0, blue: 0.4).opacity(0.4), Color(red: 0.0, green: 0.6, blue: 0.9).opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        default:
            // "red"
            ZStack {
                Color.black.opacity(0.38)
                LinearGradient(
                    colors: [Color.red.opacity(0.30), Color.black.opacity(0.12)],
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

// MARK: - Single Unified Widget Entry Point (1 Widget in Library, Multiple Instances on Desktop)
@available(macOS 14.0, *)
@main
struct YouTubeSocialWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectAccountIntent.self,
            provider: SocialAppIntentTimelineProvider()
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube & Sosyal Takip")
        .description("Masaüstünüzde YouTube, Instagram veya TikTok hesaplarınızı canlı takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
