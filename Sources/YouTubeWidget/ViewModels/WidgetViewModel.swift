import SwiftUI
import Combine

@MainActor
public final class WidgetViewModel: ObservableObject {
    public static let shared = WidgetViewModel()

    // MARK: - Published Properties
    @Published public var stats: YouTubeStats {
        didSet {
            saveCachedStats()
        }
    }

    @Published public var channelInput: String {
        didSet {
            UserDefaults.standard.set(channelInput, forKey: "YTWidget_ChannelInput")
        }
    }

    @Published public var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "YTWidget_ApiKey")
        }
    }

    @Published public var refreshIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "YTWidget_RefreshInterval")
            restartTimer()
        }
    }

    @Published public var isAlwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(isAlwaysOnTop, forKey: "YTWidget_AlwaysOnTop")
            DesktopWindowManager.shared.updateWindowLevel(isAlwaysOnTop: isAlwaysOnTop)
        }
    }

    @Published public var widgetOpacity: Double {
        didSet {
            UserDefaults.standard.set(widgetOpacity, forKey: "YTWidget_Opacity")
            DesktopWindowManager.shared.updateWindowOpacity(widgetOpacity)
        }
    }

    @Published public var showDesktopWidget: Bool {
        didSet {
            UserDefaults.standard.set(showDesktopWidget, forKey: "YTWidget_ShowDesktop")
            DesktopWindowManager.shared.setWindowVisibility(showDesktopWidget)
        }
    }

    @Published public var isLoading: Bool = false
    @Published public var lastErrorMessage: String? = nil
    @Published public var isSettingsOpen: Bool = false
    @Published public var isShortHovered: Bool = false
    @Published public var isSpinning: Bool = false

    private var refreshTimer: AnyCancellable?

    // MARK: - Init
    public init() {
        // Load settings from UserDefaults
        let savedChannel = UserDefaults.standard.string(forKey: "YTWidget_ChannelInput") ?? ""
        let savedApiKey = UserDefaults.standard.string(forKey: "YTWidget_ApiKey") ?? ""
        let savedInterval = UserDefaults.standard.integer(forKey: "YTWidget_RefreshInterval")
        let hasSavedOnTop = UserDefaults.standard.object(forKey: "YTWidget_AlwaysOnTop") != nil
        let savedOnTop = hasSavedOnTop ? UserDefaults.standard.bool(forKey: "YTWidget_AlwaysOnTop") : true
        let savedOpacity = UserDefaults.standard.double(forKey: "YTWidget_Opacity")
        let hasSavedShowDesktop = UserDefaults.standard.object(forKey: "YTWidget_ShowDesktop") != nil
        let savedShowDesktop = hasSavedShowDesktop ? UserDefaults.standard.bool(forKey: "YTWidget_ShowDesktop") : true

        self.channelInput = savedChannel
        self.apiKey = savedApiKey
        self.refreshIntervalMinutes = savedInterval > 0 ? savedInterval : 15
        self.isAlwaysOnTop = savedOnTop
        self.widgetOpacity = savedOpacity > 0.2 ? savedOpacity : 0.95
        self.showDesktopWidget = savedShowDesktop

        // Load cached stats
        if let data = UserDefaults.standard.data(forKey: "YTWidget_CachedStats"),
           let cached = try? JSONDecoder().decode(YouTubeStats.self, from: data) {
            self.stats = cached
        } else {
            // Default sample preview
            self.stats = YouTubeStats(
                channelTitle: "YouTube Widget",
                handle: "@kanal_ayarla",
                subscriberCount: "--",
                avatarURL: nil,
                latestShortTitle: "Ayarlardan YouTube kanalınızı girin",
                latestShortViews: "--",
                latestShortThumbnail: nil,
                latestShortURL: nil,
                lastUpdated: Date(),
                isConfigured: false
            )
        }

        // Start auto-refresh timer
        restartTimer()

        // If channel is configured, refresh immediately on launch
        if !savedChannel.isEmpty {
            Task {
                await self.refresh()
            }
        }
    }

    // MARK: - Actions
    public func refresh() async {
        let currentChannel = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentChannel.isEmpty else {
            self.lastErrorMessage = "Lütfen önce Ayarlar'dan bir YouTube kanalı girin."
            return
        }

        isLoading = true
        lastErrorMessage = nil

        do {
            let newStats = try await YouTubeService.shared.fetchStats(
                channelInput: currentChannel,
                apiKey: apiKey.isEmpty ? nil : apiKey
            )
            self.stats = newStats
            self.isLoading = false
            self.lastErrorMessage = nil
        } catch {
            self.isLoading = false
            self.lastErrorMessage = error.localizedDescription
            print("[YouTubeWidget Error] \(error.localizedDescription)")
        }
    }

    public func openChannel() {
        let clean = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("http") {
            if let url = URL(string: clean) {
                NSWorkspace.shared.open(url)
            }
        } else if clean.starts(with: "@") {
            if let url = URL(string: "https://www.youtube.com/\(clean)") {
                NSWorkspace.shared.open(url)
            }
        } else if clean.starts(with: "UC") && clean.count == 24 {
            if let url = URL(string: "https://www.youtube.com/channel/\(clean)") {
                NSWorkspace.shared.open(url)
            }
        } else if !stats.handle.isEmpty && stats.handle.starts(with: "@") {
            if let url = URL(string: "https://www.youtube.com/\(stats.handle)") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "https://www.youtube.com") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    public func openLatestShort() {
        if let shortURL = stats.latestShortURL, let url = URL(string: shortURL) {
            NSWorkspace.shared.open(url)
        } else {
            openChannel()
        }
    }

    private func restartTimer() {
        refreshTimer?.cancel()
        let intervalSeconds = TimeInterval(max(1, refreshIntervalMinutes) * 60)
        refreshTimer = Timer.publish(every: intervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refresh()
                }
            }
    }

    private func saveCachedStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: "YTWidget_CachedStats")
        }
    }
}
