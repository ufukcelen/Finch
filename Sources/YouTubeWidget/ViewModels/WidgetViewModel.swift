import SwiftUI
import Combine
import AppKit

public enum WidgetSize: String, CaseIterable, Codable, Sendable {
    case small = "small"
    case medium = "medium"

    public var displayName: String {
        switch self {
        case .small: return "Küçük (Yalnızca Abone/Takipçi)"
        case .medium: return "Orta (Genişletilmiş İstatistik)"
        }
    }
}

@MainActor
public final class WidgetViewModel: ObservableObject {
    public static let shared = WidgetViewModel()

    // MARK: - Published Properties
    @Published public var accounts: [String: SocialAccountStats] = [:] {
        didSet {
            saveAccountsToDisk()
        }
    }

    @Published public var activeSlot: String = "youtube1"

    @Published public var refreshIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "YTWidget_RefreshInterval")
            restartTimer()
            syncToSharedData()
        }
    }

    @Published public var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "YTWidget_ApiKey")
        }
    }

    @Published public var isLoading: Bool = false
    @Published public var lastErrorMessage: String? = nil

    // Legacy wrappers for MenuBar & compatibility
    public var channelInput: String {
        get { accounts["youtube1"]?.handle ?? "" }
        set { accounts["youtube1"]?.handle = newValue }
    }

    public var theme: String {
        get { accounts["youtube1"]?.theme ?? "red" }
        set { accounts["youtube1"]?.theme = newValue }
    }

    public var stats: YouTubeStats {
        let y = accounts["youtube1"]
        return YouTubeStats(
            channelTitle: y?.title ?? "YouTube Widget",
            handle: y?.handle ?? "@kanal_ayarla",
            subscriberCount: y?.mainStatCount ?? "--",
            avatarURL: y?.avatarURL,
            latestShortTitle: y?.secondaryTitle ?? "",
            latestShortViews: y?.secondaryValue ?? "--",
            latestShortThumbnail: y?.thumbnailURL,
            latestShortURL: y?.contentURL,
            lastUpdated: y?.lastUpdated ?? Date(),
            isConfigured: y?.isConfigured ?? false
        )
    }

    public var primaryAccountDisplayCount: String {
        if let y1 = accounts["youtube1"], y1.isConfigured, y1.mainStatCount != "--" {
            let parts = y1.mainStatCount.split(separator: " ")
            return String(parts.first ?? "")
        }
        return "--"
    }

    public var hasAnyConfiguredAccount: Bool {
        accounts.values.contains { $0.isConfigured }
    }

    private var refreshTimer: AnyCancellable?

    // MARK: - Init
    public init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "YTWidget_RefreshInterval")
        let validIntervals = [120, 360, 720, 1440]
        self.refreshIntervalMinutes = validIntervals.contains(savedInterval) ? savedInterval : 360
        self.apiKey = UserDefaults.standard.string(forKey: "YTWidget_ApiKey") ?? ""

        // Load existing accounts or initialize defaults
        var loaded = SharedDataManager.shared.loadAccounts() ?? [:]
        if loaded["youtube"] == nil && loaded["youtube1"] == nil {
            let legacyChannel = UserDefaults.standard.string(forKey: "YTWidget_ChannelInput") ?? ""
            var sample = SocialAccountStats.defaultSample(for: "youtube", platform: .youtube)
            if !legacyChannel.isEmpty {
                sample.handle = legacyChannel
                sample.isConfigured = true
            }
            loaded["youtube"] = sample
            loaded["youtube1"] = sample
        } else if loaded["youtube"] == nil, let y1 = loaded["youtube1"] {
            loaded["youtube"] = y1
        } else if loaded["youtube1"] == nil, let y = loaded["youtube"] {
            loaded["youtube1"] = y
        }
        if loaded["instagram"] == nil {
            loaded["instagram"] = SocialAccountStats.defaultSample(for: "instagram", platform: .instagram)
        }
        if loaded["tiktok"] == nil {
            loaded["tiktok"] = SocialAccountStats.defaultSample(for: "tiktok", platform: .tiktok)
        }

        self.accounts = loaded

        DebugLogger.shared.log(.info, tag: "WidgetViewModel", message: "WidgetViewModel başlatıldı. Hesap sayısı: \(loaded.count)")

        // Start auto-refresh timer (2h, 6h, 12h, or 24h)
        restartTimer()

        // Sync to Widget Extension disk container
        syncToSharedData()

        // Refresh configured accounts on launch
        Task {
            await self.refreshAll()
        }
    }

    // MARK: - Save & Refresh
    public func saveAccount(
        slotID: String,
        platform: SocialPlatform,
        input: String,
        theme: String,
        apiKey: String?
    ) async throws {
        isLoading = true
        lastErrorMessage = nil
        DebugLogger.shared.log(.info, tag: "WidgetViewModel", message: "Hesap kaydediliyor: \(slotID) (\(platform.displayName)) -> \(input)")

        do {
            let newStats = try await SocialService.shared.fetchStats(
                slotID: slotID,
                platform: platform,
                input: input,
                apiKey: apiKey,
                theme: theme
            )
            self.accounts[slotID] = newStats
            if slotID == "youtube" {
                self.accounts["youtube1"] = newStats
            } else if slotID == "youtube1" {
                self.accounts["youtube"] = newStats
            }
            self.isLoading = false
            syncToSharedData()
            DebugLogger.shared.log(.info, tag: "WidgetViewModel", message: "Hesap başarıyla kaydedildi: \(slotID)")
        } catch {
            self.isLoading = false
            self.lastErrorMessage = error.localizedDescription
            DebugLogger.shared.log(.error, tag: "WidgetViewModel", message: "Hesap kaydetme hatası: \(error.localizedDescription)")
            throw error
        }
    }

    public func refreshSlot(_ slotID: String) async {
        guard let acc = accounts[slotID], acc.isConfigured else { return }
        let input = acc.handle.isEmpty ? acc.title : acc.handle
        guard !input.isEmpty else { return }

        DebugLogger.shared.log(.info, tag: "WidgetViewModel", message: "Slot yenileniyor: \(slotID)")
        do {
            let updated = try await SocialService.shared.fetchStats(
                slotID: slotID,
                platform: acc.platform,
                input: input,
                apiKey: (acc.platform == .youtube && !apiKey.isEmpty) ? apiKey : nil,
                theme: acc.theme
            )
            self.accounts[slotID] = updated
            syncToSharedData()
        } catch {
            DebugLogger.shared.log(.error, tag: "WidgetViewModel", message: "Slot \(slotID) yenileme hatası: \(error)")
        }
    }

    public func refreshAll() async {
        isLoading = true
        DebugLogger.shared.log(.info, tag: "WidgetViewModel", message: "Tüm aktif slotlar yenileniyor...")
        for slot in ["youtube1", "youtube2", "instagram", "tiktok"] {
            if let acc = accounts[slot], acc.isConfigured {
                await refreshSlot(slot)
            }
        }
        isLoading = false
    }

    // Legacy method for MenuBarView
    public func refresh() async {
        await refreshAll()
    }

    public func openChannel() {
        if let y1 = accounts["youtube1"], let url = URL(string: y1.profileURL) {
            NSWorkspace.shared.open(url)
        }
    }

    public func openLatestShort() {
        if let y1 = accounts["youtube1"], let s = y1.contentURL, let url = URL(string: s) {
            NSWorkspace.shared.open(url)
        } else {
            openChannel()
        }
    }

    // MARK: - Private
    private func restartTimer() {
        refreshTimer?.cancel()
        let intervalSeconds = TimeInterval(max(60, refreshIntervalMinutes) * 60)
        refreshTimer = Timer.publish(every: intervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshAll()
                }
            }
    }

    private func saveAccountsToDisk() {
        syncToSharedData()
    }

    public func syncToSharedData() {
        SharedDataManager.shared.saveAll(
            accounts: accounts,
            refreshIntervalMinutes: refreshIntervalMinutes
        )
    }
}
