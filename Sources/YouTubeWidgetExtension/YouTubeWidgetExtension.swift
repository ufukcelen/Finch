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

// MARK: - Timeline Provider
struct SocialTimelineProvider: TimelineProvider {
    let slotID: String
    let defaultPlatform: SocialPlatform

    func placeholder(in context: Context) -> SocialTimelineEntry {
        loadEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (SocialTimelineEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SocialTimelineEntry>) -> Void) {
        let entry = loadEntry()
        let interval = loadRefreshInterval()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: interval, to: Date()) ?? Date().addingTimeInterval(TimeInterval(interval * 60))
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> SocialTimelineEntry {
        let stats = loadSharedStats(for: slotID) ?? SocialAccountStats.defaultSample(for: slotID, platform: defaultPlatform)
        let avatar = loadLocalImage(named: "avatar_\(slotID).png", fallbackName: slotID == "youtube1" ? "avatar.png" : nil)
        let thumb = loadLocalImage(named: "thumbnail_\(slotID).png", fallbackName: slotID == "youtube1" ? "thumbnail.png" : nil)
        return SocialTimelineEntry(date: Date(), stats: stats, avatarImage: avatar, thumbnailImage: thumb)
    }

    private func loadSharedStats(for slot: String) -> SocialAccountStats? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("YouTubeWidget/shared_data.json")

        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Try reading from multi-account map
        if let accountsDict = json["accounts"] as? [String: [String: Any]],
           let slotDict = accountsDict[slot],
           let slotData = try? JSONSerialization.data(withJSONObject: slotDict),
           let acc = try? JSONDecoder().decode(SocialAccountStats.self, from: slotData) {
            return acc
        }

        // Backward compatibility for slot youtube1
        if slot == "youtube1", let statsDict = json["stats"] as? [String: Any] {
            let theme = json["theme"] as? String ?? "red"
            var acc = SocialAccountStats.defaultSample(for: "youtube1", platform: .youtube)
            acc.title = statsDict["channelTitle"] as? String ?? "YouTube Kanalı"
            acc.handle = statsDict["handle"] as? String ?? "@kanal"
            acc.mainStatCount = statsDict["subscriberCount"] as? String ?? "--"
            acc.avatarURL = statsDict["avatarURL"] as? String
            acc.secondaryTitle = statsDict["latestShortTitle"] as? String ?? ""
            acc.secondaryValue = statsDict["latestShortViews"] as? String ?? "--"
            acc.thumbnailURL = statsDict["latestShortThumbnail"] as? String
            acc.contentURL = statsDict["latestShortURL"] as? String
            acc.theme = theme
            acc.isConfigured = true
            return acc
        }

        return nil
    }

    private func loadRefreshInterval() -> Int {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("YouTubeWidget/shared_data.json")
        if let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let interval = json["refreshIntervalMinutes"] as? Int, interval > 0 {
            return interval
        }
        return 360 // Default 6 hours
    }

    private func loadLocalImage(named: String, fallbackName: String?) -> NSImage? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let primaryURL = appSupport.appendingPathComponent("YouTubeWidget/\(named)")
        if let data = try? Data(contentsOf: primaryURL), let img = NSImage(data: data) {
            return img
        }
        if let fb = fallbackName {
            let fallbackURL = appSupport.appendingPathComponent("YouTubeWidget/\(fb)")
            if let data = try? Data(contentsOf: fallbackURL), let img = NSImage(data: data) {
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

    // MARK: - SystemSmall View (Yalnızca Takipçi / Abone Sayısı)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Avatar + Title + Settings Gear Button
            HStack(spacing: 7) {
                // Avatar + Platform icon
                Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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
                Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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
                .help("Widget Ayarları & Kanal Değiştir")
            }

            Spacer(minLength: 0)

            // Main Stat Count (Abone / Takipçi)
            Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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
                    Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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

                    Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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

                Link(destination: URL(string: entry.stats.profileURL.isEmpty ? "https://youtube.com" : entry.stats.profileURL)!) {
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
            Link(destination: URL(string: entry.stats.contentURL ?? entry.stats.profileURL)!) {
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
            Link(destination: URL(string: entry.stats.profileURL)!) {
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
            Link(destination: URL(string: entry.stats.profileURL)!) {
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
        case "purple":
            ZStack {
                Color.black.opacity(0.45)
                LinearGradient(
                    colors: [Color(red: 0.88, green: 0.19, blue: 0.42).opacity(0.35), Color(red: 0.4, green: 0.1, blue: 0.7).opacity(0.35)],
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

// MARK: - Widget Configurations
struct YouTubePrimaryWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SocialTimelineProvider(slotID: "youtube1", defaultPlatform: .youtube)) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube (Ana Kanal)")
        .description("YouTube abone sayınızı ve son Shorts videonuzu masaüstünüzde takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct YouTubeSecondaryWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.youtube2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SocialTimelineProvider(slotID: "youtube2", defaultPlatform: .youtube)) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube (2. Kanal)")
        .description("İkinci YouTube kanalınızın abone sayısını ve videosunu masaüstünüzde takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct InstagramWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.instagram"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SocialTimelineProvider(slotID: "instagram", defaultPlatform: .instagram)) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Instagram Widget")
        .description("Instagram takipçi ve gönderi sayınızı masaüstünüzde takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct TikTokWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension.tiktok"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SocialTimelineProvider(slotID: "tiktok", defaultPlatform: .tiktok)) { entry in
            SocialWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TikTok Widget")
        .description("TikTok takipçi ve beğeni sayınızı masaüstünüzde takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Multi-Widget Bundle
@main
struct SocialWidgetBundle: WidgetBundle {
    var body: some Widget {
        YouTubePrimaryWidget()
        YouTubeSecondaryWidget()
        InstagramWidget()
        TikTokWidget()
    }
}
