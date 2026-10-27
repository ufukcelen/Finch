import WidgetKit
import SwiftUI
import AppKit
import AppIntents

// MARK: - App Intents (Per-Widget Configuration on macOS Desktop)

@available(macOS 14.0, *)
public enum WidgetSlotChoice: String, AppEnum, Sendable {
    case slot1 = "slot1"
    case slot2 = "slot2"
    case slot3 = "slot3"
    case slot4 = "slot4"
    case custom = "custom"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hesap / Slot"
    public static var caseDisplayRepresentations: [WidgetSlotChoice: DisplayRepresentation] = [
        .slot1: "1. Slot (Ana YouTube Kanalı)",
        .slot2: "2. Slot (2. YouTube Kanalı)",
        .slot3: "3. Slot (Instagram)",
        .slot4: "4. Slot (TikTok)",
        .custom: "✍️ Özel Kanal Yaz"
    ]
}

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
    public static var description = IntentDescription("Bu widget'ın göstereceği hesabı, temasını ve güncelleme sıklığını belirleyin.")

    @Parameter(title: "Hesap Seçimi", default: .slot1)
    public var slot: WidgetSlotChoice

    @Parameter(title: "Özel Kanal / Kullanıcı Adı", default: "")
    public var customHandle: String

    @Parameter(title: "Özel Platform", default: .youtube)
    public var customPlatform: WidgetPlatform

    @Parameter(title: "Yenileme Sıklığı", default: .sixHours)
    public var refreshInterval: WidgetRefreshInterval

    @Parameter(title: "Görünüm Teması", default: .red)
    public var theme: WidgetTheme

    public init() {}

    public init(
        slot: WidgetSlotChoice = .slot1,
        customHandle: String = "",
        customPlatform: WidgetPlatform = .youtube,
        refreshInterval: WidgetRefreshInterval = .sixHours,
        theme: WidgetTheme = .red
    ) {
        self.slot = slot
        self.customHandle = customHandle
        self.customPlatform = customPlatform
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

// MARK: - Timeline Provider
@available(macOS 14.0, *)
struct SocialAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialTimelineEntry {
        let sample = SocialAccountStats.defaultSample(for: "placeholder", platform: .youtube)
        return SocialTimelineEntry(date: Date(), stats: sample, avatarImage: nil, thumbnailImage: nil)
    }

    func snapshot(for configuration: SelectAccountIntent, in context: Context) async -> SocialTimelineEntry {
        return await loadEntry(for: configuration)
    }

    func timeline(for configuration: SelectAccountIntent, in context: Context) async -> Timeline<SocialTimelineEntry> {
        let entry = await loadEntry(for: configuration)
        let intervalHours = configuration.refreshInterval.rawValue

        let nextDate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalHours * 3600))

        return Timeline(entries: [entry], policy: .after(nextDate))
    }

    // MARK: - Entry Loader
    private func loadEntry(for configuration: SelectAccountIntent) async -> SocialTimelineEntry {
        let themeName = configuration.theme.rawValue

        // Case 1: Custom handle specified
        if configuration.slot == .custom {
            let handle = configuration.customHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            let platform = configuration.customPlatform.toSocialPlatform()
            if !handle.isEmpty {
                return await fetchCustomLiveEntry(platform: platform, handle: handle, theme: themeName)
            }
        }

        // Case 2: Slot selected (.slot1, .slot2, .slot3, .slot4)
        let slotID: String
        let fallbackPlatform: SocialPlatform
        switch configuration.slot {
        case .slot2:
            slotID = "youtube2"
            fallbackPlatform = .youtube
        case .slot3:
            slotID = "instagram"
            fallbackPlatform = .instagram
        case .slot4:
            slotID = "tiktok"
            fallbackPlatform = .tiktok
        default:
            slotID = "youtube1"
            fallbackPlatform = .youtube
        }

        // Try to load saved account from shared_data.json
        if var saved = loadLocalStats(forSlot: slotID) {
            if themeName != "red" {
                saved.theme = themeName
            }
            let avatar = loadAvatar(slotID: slotID)
            let thumb = loadThumbnail(slotID: slotID)
            return SocialTimelineEntry(date: Date(), stats: saved, avatarImage: avatar, thumbnailImage: thumb)
        }

        // If not saved yet, try slot1 fallback or default sample
        if slotID != "youtube1", var primary = loadLocalStats(forSlot: "youtube1") {
            if themeName != "red" {
                primary.theme = themeName
            }
            let avatar = loadAvatar(slotID: "youtube1")
            let thumb = loadThumbnail(slotID: "youtube1")
            return SocialTimelineEntry(date: Date(), stats: primary, avatarImage: avatar, thumbnailImage: thumb)
        }

        let sample = SocialAccountStats.defaultSample(for: slotID, platform: fallbackPlatform)
        return SocialTimelineEntry(date: Date(), stats: sample, avatarImage: nil, thumbnailImage: nil)
    }

    private func fetchCustomLiveEntry(platform: SocialPlatform, handle: String, theme: String) async -> SocialTimelineEntry {
        let safeKey = "custom_\(platform.rawValue)_\(handle.replacingOccurrences(of: "@", with: "").replacingOccurrences(of: "/", with: "_"))"

        var stats: SocialAccountStats? = nil
        do {
            stats = try await SocialService.shared.fetchStats(
                slotID: safeKey,
                platform: platform,
                input: handle,
                apiKey: nil,
                theme: theme
            )
        } catch {
            print("[WidgetProvider] Live fetch error: \(error.localizedDescription)")
        }

        let dir = containerURL()
        var avatarImg: NSImage? = nil
        var thumbImg: NSImage? = nil

        if let live = stats {
            // Cache images locally
            if let avURLStr = live.avatarURL, let url = URL(string: avURLStr),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                avatarImg = NSImage(data: data)
                let avFile = dir.appendingPathComponent("avatar_\(safeKey).png")
                try? data.write(to: avFile)
            }
            if let thURLStr = live.thumbnailURL, let url = URL(string: thURLStr),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                thumbImg = NSImage(data: data)
                let thFile = dir.appendingPathComponent("thumb_\(safeKey).png")
                try? data.write(to: thFile)
            }
        }

        let finalStats = stats ?? SocialAccountStats.defaultSample(for: safeKey, platform: platform)
        return SocialTimelineEntry(date: Date(), stats: finalStats, avatarImage: avatarImg, thumbnailImage: thumbImg)
    }

    // MARK: - Local Data & Image Helpers
    private func containerURL() -> URL {
        // 1. Sandboxed Application Support Directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let candidate = appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true)
            let file = candidate.appendingPathComponent("shared_data.json")
            if FileManager.default.fileExists(atPath: file.path) {
                return candidate
            }
        }

        // 2. Direct Container path if running outside or with home directory
        let home = FileManager.default.homeDirectoryForCurrentUser
        let direct = home.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        if FileManager.default.fileExists(atPath: direct.appendingPathComponent("shared_data.json").path) {
            return direct
        }

        // 3. Fallback standard Application Support
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    private func loadLocalStats(forSlot slotID: String) -> SocialAccountStats? {
        let dir = containerURL()
        let file = dir.appendingPathComponent("shared_data.json")

        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accountsDict = json["accounts"] as? [String: [String: Any]] else {
            return nil
        }

        // 1. Exact slot key match
        if let slotData = accountsDict[slotID],
           let serialized = try? JSONSerialization.data(withJSONObject: slotData),
           let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: serialized) {
            return acc
        }

        // 2. Legacy fallback for youtube1
        if slotID == "youtube1", let legacyStats = json["stats"] as? [String: Any],
           let serialized = try? JSONSerialization.data(withJSONObject: legacyStats),
           let ytStats = try? JSONDecoder().decode(YouTubeStats.self, from: serialized) {
            let th = json["theme"] as? String ?? "red"
            return SocialAccountStats(
                slotID: "youtube1",
                platform: .youtube,
                title: ytStats.channelTitle,
                handle: ytStats.handle,
                mainStatCount: ytStats.subscriberCount,
                secondaryTitle: ytStats.latestShortTitle,
                secondaryValue: ytStats.latestShortViews,
                avatarURL: ytStats.avatarURL,
                thumbnailURL: ytStats.latestShortThumbnail,
                profileURL: ytStats.handle.starts(with: "@") ? "https://www.youtube.com/\(ytStats.handle)" : "https://www.youtube.com",
                contentURL: ytStats.latestShortURL,
                theme: th,
                lastUpdated: ytStats.lastUpdated,
                isConfigured: ytStats.isConfigured
            )
        }

        return nil
    }

    private func loadAvatar(slotID: String) -> NSImage? {
        let dir = containerURL()
        let candidates = [
            "avatar_\(slotID).png",
            "avatar.png"
        ]
        for name in candidates {
            let file = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
                return img
            }
        }
        return nil
    }

    private func loadThumbnail(slotID: String) -> NSImage? {
        let dir = containerURL()
        let candidates = [
            "thumbnail_\(slotID).png",
            "thumbnail.png"
        ]
        for name in candidates {
            let file = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
                return img
            }
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

                // ⚙️ Settings Gear Button (Directly opens Settings for this slot)
                Link(destination: URL(string: "youtubewidget://settings?slot=\(entry.stats.slotID)")!) {
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
                    Link(destination: URL(string: "youtubewidget://settings?slot=\(entry.stats.slotID)")!) {
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

// MARK: - Single Unified Widget Entry Point
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
