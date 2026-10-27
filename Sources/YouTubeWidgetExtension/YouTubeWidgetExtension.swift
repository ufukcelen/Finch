import WidgetKit
import SwiftUI
import AppKit

// MARK: - Timeline Entry
struct SocialTimelineEntry: TimelineEntry {
    let date: Date
    let stats: SocialAccountStats
    let avatarImage: NSImage?
    let thumbnailImage: NSImage?
}

// MARK: - Generic Slot Timeline Provider
struct SocialTimelineProvider: TimelineProvider {
    let slotID: String
    let defaultPlatform: SocialPlatform

    func placeholder(in context: Context) -> SocialTimelineEntry {
        let sample = SocialAccountStats.defaultSample(for: slotID, platform: defaultPlatform)
        return SocialTimelineEntry(date: Date(), stats: sample, avatarImage: nil, thumbnailImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SocialTimelineEntry) -> Void) {
        let entry = loadLocalEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SocialTimelineEntry>) -> Void) {
        let entry = loadLocalEntry()
        let intervalMinutes = loadRefreshInterval()
        let nextDate = Calendar.current.date(byAdding: .minute, value: intervalMinutes, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(intervalMinutes * 60))

        let timeline = Timeline(entries: [entry], policy: .after(nextDate))
        completion(timeline)
    }

    // MARK: - Helpers
    private func containerURL() -> URL {
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        let dir = userHome.appendingPathComponent("Library/Containers/com.ufukcelen.youtubewidget.extension/Data/Library/Application Support/YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadRefreshInterval() -> Int {
        let file = containerURL().appendingPathComponent("shared_data.json")
        if let data = try? Data(contentsOf: file),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let interval = json["refreshIntervalMinutes"] as? Int, interval > 0 {
            return interval
        }
        return 360 // Default 6 hours
    }

    private func loadLocalEntry() -> SocialTimelineEntry {
        let dir = containerURL()
        let file = dir.appendingPathComponent("shared_data.json")

        var foundStats: SocialAccountStats? = nil
        if let data = try? Data(contentsOf: file),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            // 1. Try from accounts dictionary
            if let accountsDict = json["accounts"] as? [String: [String: Any]],
               let slotDict = accountsDict[slotID],
               let accData = try? JSONSerialization.data(withJSONObject: slotDict),
               let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: accData) {
                foundStats = acc
            }

            // 2. Fallback to legacy root stats if primary slot
            if foundStats == nil && slotID == "youtube1",
               let legacyStats = json["stats"] as? [String: Any],
               let statsData = try? JSONSerialization.data(withJSONObject: legacyStats),
               let ytStats = try? JSONDecoder().decode(YouTubeStats.self, from: statsData) {
                let theme = json["theme"] as? String ?? "red"
                foundStats = SocialAccountStats(
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
                    theme: theme,
                    lastUpdated: ytStats.lastUpdated,
                    isConfigured: ytStats.isConfigured
                )
            }
        }

        let stats = foundStats ?? SocialAccountStats.defaultSample(for: slotID, platform: defaultPlatform)

        // Load cached avatar image
        var avatar: NSImage? = nil
        let avatarFile = dir.appendingPathComponent("avatar_\(slotID).png")
        if let data = try? Data(contentsOf: avatarFile) {
            avatar = NSImage(data: data)
        } else if slotID == "youtube1", let legacyAvatar = try? Data(contentsOf: dir.appendingPathComponent("avatar.png")) {
            avatar = NSImage(data: legacyAvatar)
        }

        // Load cached thumbnail image
        var thumb: NSImage? = nil
        let thumbFile = dir.appendingPathComponent("thumbnail_\(slotID).png")
        if let data = try? Data(contentsOf: thumbFile) {
            thumb = NSImage(data: data)
        } else if slotID == "youtube1", let legacyThumb = try? Data(contentsOf: dir.appendingPathComponent("thumbnail.png")) {
            thumb = NSImage(data: legacyThumb)
        }

        return SocialTimelineEntry(
            date: Date(),
            stats: stats,
            avatarImage: avatar,
            thumbnailImage: thumb
        )
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

    // MARK: - SystemSmall View (Yalnızca Takipçi / Abone Sayısı)
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

                // ⚙️ Settings Gear Button (Opens helper app directly to this widget's slot)
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
                .help("Widget Ayarları & Kanal Değiştir")
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
                    .help("Widget Ayarları & Kanal Değiştir")
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

// MARK: - Widgets Definition

// 1. Primary Widget (Slot 1)
struct YouTubeSocialWidget1: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SocialTimelineProvider(slotID: "youtube1", defaultPlatform: .youtube)
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube & Sosyal Takip")
        .description("YouTube, Instagram veya TikTok hesabınızı canlı takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// 2. Secondary Widget (Slot 2)
struct YouTubeSocialWidget2: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.youtube2"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SocialTimelineProvider(slotID: "youtube2", defaultPlatform: .youtube)
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sosyal Takip 2")
        .description("İkinci bir sosyal medya veya YouTube kanalınızı takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// 3. Instagram Widget (Slot 3)
struct InstagramSocialWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.instagram"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SocialTimelineProvider(slotID: "instagram", defaultPlatform: .instagram)
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Instagram Takip")
        .description("Instagram takipçi ve gönderi sayınızı canlı görüntüleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// 4. TikTok Widget (Slot 4)
struct TikTokSocialWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.tiktok"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SocialTimelineProvider(slotID: "tiktok", defaultPlatform: .tiktok)
        ) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TikTok Takip")
        .description("TikTok takipçi ve beğeni sayınızı canlı görüntüleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Bundle (Main Entry Point)
@main
struct YouTubeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        YouTubeSocialWidget1()
        YouTubeSocialWidget2()
        InstagramSocialWidget()
        TikTokSocialWidget()
    }
}
