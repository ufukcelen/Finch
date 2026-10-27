import WidgetKit
import SwiftUI
import AppKit

// MARK: - Models
public struct ExtensionYouTubeStats: Codable, Sendable {
    public var channelTitle: String
    public var handle: String
    public var subscriberCount: String
    public var avatarURL: String?
    public var latestShortTitle: String
    public var latestShortViews: String
    public var latestShortThumbnail: String?
    public var latestShortURL: String?

    public init(
        channelTitle: String = "YouTube Kanalı",
        handle: String = "@kanal",
        subscriberCount: String = "--",
        avatarURL: String? = nil,
        latestShortTitle: String = "Son video yüklenmedi",
        latestShortViews: String = "--",
        latestShortThumbnail: String? = nil,
        latestShortURL: String? = nil
    ) {
        self.channelTitle = channelTitle
        self.handle = handle
        self.subscriberCount = subscriberCount
        self.avatarURL = avatarURL
        self.latestShortTitle = latestShortTitle
        self.latestShortViews = latestShortViews
        self.latestShortThumbnail = latestShortThumbnail
        self.latestShortURL = latestShortURL
    }

    public static let sample = ExtensionYouTubeStats(
        channelTitle: "Örnek Kanal",
        handle: "@ornekkanal",
        subscriberCount: "125.4K",
        avatarURL: nil,
        latestShortTitle: "Harika Yeni macOS Widget! #shorts",
        latestShortViews: "48.2K izlenme",
        latestShortThumbnail: nil,
        latestShortURL: nil
    )
}

struct YouTubeTimelineEntry: TimelineEntry {
    let date: Date
    let stats: ExtensionYouTubeStats
    let avatarImage: NSImage?
    let thumbnailImage: NSImage?
}

// MARK: - Timeline Provider
struct YouTubeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> YouTubeTimelineEntry {
        YouTubeTimelineEntry(
            date: Date(),
            stats: .sample,
            avatarImage: nil,
            thumbnailImage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (YouTubeTimelineEntry) -> Void) {
        let stats = loadSharedStats() ?? .sample
        let avatar = loadImage(from: stats.avatarURL)
        let thumb = loadImage(from: stats.latestShortThumbnail)
        let entry = YouTubeTimelineEntry(
            date: Date(),
            stats: stats,
            avatarImage: avatar,
            thumbnailImage: thumb
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YouTubeTimelineEntry>) -> Void) {
        let stats = loadSharedStats() ?? .sample
        let avatar = loadImage(from: stats.avatarURL)
        let thumb = loadImage(from: stats.latestShortThumbnail)
        let entry = YouTubeTimelineEntry(
            date: Date(),
            stats: stats,
            avatarImage: avatar,
            thumbnailImage: thumb
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadSharedStats() -> ExtensionYouTubeStats? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("YouTubeWidget/shared_data.json")

        if let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let statsDict = json["stats"] as? [String: Any] {
            var stats = ExtensionYouTubeStats()
            stats.channelTitle = statsDict["channelTitle"] as? String ?? "YouTube Kanalı"
            stats.handle = statsDict["handle"] as? String ?? "@kanal"
            stats.subscriberCount = statsDict["subscriberCount"] as? String ?? "--"
            stats.avatarURL = statsDict["avatarURL"] as? String
            stats.latestShortTitle = statsDict["latestShortTitle"] as? String ?? ""
            stats.latestShortViews = statsDict["latestShortViews"] as? String ?? "--"
            stats.latestShortThumbnail = statsDict["latestShortThumbnail"] as? String
            stats.latestShortURL = statsDict["latestShortURL"] as? String
            return stats
        }
        return nil
    }

    private func loadImage(from urlString: String?) -> NSImage? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        if let data = try? Data(contentsOf: url) {
            return NSImage(data: data)
        }
        return nil
    }
}

// MARK: - Widget Views
struct YouTubeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: YouTubeTimelineEntry

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

    // MARK: - SystemSmall View (Yalnızca Abone Sayısı - No Video)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Avatar + Channel Info
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let img = entry.avatarImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            )
                    }

                    Circle()
                        .fill(Color(red: 1.0, green: 0.1, blue: 0.1))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 0.5)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.stats.channelTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(entry.stats.handle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Subscriber Count
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.stats.subscriberCount)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                                .scaleEffect(1.6)
                        )
                }

                Text("ABONE SAYISI")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
            }

            Spacer(minLength: 0)

            HStack {
                Text("🔴 YouTube")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.red)

                Spacer()

                Text("Canlı")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
    }

    // MARK: - SystemMedium View (Abone Sayısı + Son Shorts)
    private var mediumWidgetView: some View {
        HStack(spacing: 12) {
            // Left Column: Channel & Subscriber Count
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let img = entry.avatarImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.stats.channelTitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(entry.stats.handle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(entry.stats.subscriberCount)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .lineLimit(1)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                    }

                    Text("ABONE SAYISI")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                }

                Spacer(minLength: 0)

                Text("🔴 YouTube Widget")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .opacity(0.4)

            // Right Column: Latest Short Card
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
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 44, height: 60)
                            .overlay(
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.stats.latestShortTitle.isEmpty ? "Son Short Yüklenmedi" : entry.stats.latestShortTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.system(size: 9))
                            Text(entry.stats.latestShortViews)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Widget Configuration
struct YouTubeSystemWidget: Widget {
    let kind: String = "com.ufukcelen.youtubewidget.extension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YouTubeTimelineProvider()) { entry in
            YouTubeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YouTube Kanalı")
        .description("Abone sayınızı ve son Shorts videonuzu masaüstünüzde takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct YouTubeWidgetBundle: WidgetBundle {
    var body: some Widget {
        YouTubeSystemWidget()
    }
}
