import Foundation
import Testing
@testable import YouTubeWidget

// MARK: - SocialPlatform Tests
@Suite("SocialPlatform Tests")
struct SocialPlatformTests {

    @Test("Display names are correct")
    func displayNames() {
        #expect(SocialPlatform.youtube.displayName == "YouTube")
        #expect(SocialPlatform.instagram.displayName == "Instagram")
        #expect(SocialPlatform.tiktok.displayName == "TikTok")
    }

    @Test("Icon names are correct")
    func iconNames() {
        #expect(SocialPlatform.youtube.iconName == "play.rectangle.fill")
        #expect(SocialPlatform.instagram.iconName == "camera.fill")
        #expect(SocialPlatform.tiktok.iconName == "music.note")
    }

    @Test("Brand color hex values")
    func brandColorHex() {
        #expect(SocialPlatform.youtube.brandColorHex == "#FF0000")
        #expect(SocialPlatform.instagram.brandColorHex == "#E1306C")
        #expect(SocialPlatform.tiktok.brandColorHex == "#00F2FE")
    }

    @Test("Stat titles")
    func statTitles() {
        #expect(SocialPlatform.youtube.statTitle == "ABONE SAYISI")
        #expect(SocialPlatform.instagram.statTitle == "TAKİPÇİ SAYISI")
        #expect(SocialPlatform.tiktok.statTitle == "TAKİPÇİ SAYISI")
    }

    @Test("Secondary titles")
    func secondaryTitles() {
        #expect(SocialPlatform.youtube.secondaryTitle == "SON SHORTS")
        #expect(SocialPlatform.instagram.secondaryTitle == "GÖNDERİLER")
        #expect(SocialPlatform.tiktok.secondaryTitle == "BEĞENİLER")
    }

    @Test("Raw values")
    func rawValues() {
        #expect(SocialPlatform.youtube.rawValue == "youtube")
        #expect(SocialPlatform.instagram.rawValue == "instagram")
        #expect(SocialPlatform.tiktok.rawValue == "tiktok")
    }

    @Test("CaseIterable has 3 cases")
    func caseIterable() {
        #expect(SocialPlatform.allCases.count == 3)
        #expect(SocialPlatform.allCases.contains(.youtube))
        #expect(SocialPlatform.allCases.contains(.instagram))
        #expect(SocialPlatform.allCases.contains(.tiktok))
    }

    @Test("Codable roundtrip for all platforms")
    func codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for platform in SocialPlatform.allCases {
            let data = try encoder.encode(platform)
            let decoded = try decoder.decode(SocialPlatform.self, from: data)
            #expect(platform == decoded, "Codable roundtrip failed for \(platform)")
        }
    }
}

// MARK: - SocialAccountStats Tests
@Suite("SocialAccountStats Tests")
struct SocialAccountStatsTests {

    @Test("Default init values")
    func defaultInit() {
        let stats = SocialAccountStats(slotID: "test1")
        #expect(stats.slotID == "test1")
        #expect(stats.platform == SocialPlatform.youtube)
        #expect(stats.title == "")
        #expect(stats.handle == "")
        #expect(stats.mainStatCount == "--")
        #expect(stats.secondaryTitle == "")
        #expect(stats.secondaryValue == "--")
        #expect(stats.avatarURL == nil)
        #expect(stats.thumbnailURL == nil)
        #expect(stats.profileURL == "")
        #expect(stats.contentURL == nil)
        #expect(stats.theme == "red")
        #expect(stats.isConfigured == false)
    }

    @Test("Custom init values")
    func customInit() {
        let date = Date(timeIntervalSince1970: 1000000)
        let stats = SocialAccountStats(
            slotID: "instagram",
            platform: .instagram,
            title: "Test User",
            handle: "@testuser",
            mainStatCount: "100K",
            secondaryTitle: "Posts",
            secondaryValue: "500 Gönderi",
            avatarURL: "https://example.com/avatar.jpg",
            thumbnailURL: "https://example.com/thumb.jpg",
            profileURL: "https://instagram.com/testuser",
            contentURL: "https://instagram.com/testuser/post/1",
            theme: "purple",
            lastUpdated: date,
            isConfigured: true
        )

        #expect(stats.slotID == "instagram")
        #expect(stats.platform == SocialPlatform.instagram)
        #expect(stats.title == "Test User")
        #expect(stats.handle == "@testuser")
        #expect(stats.mainStatCount == "100K")
        #expect(stats.theme == "purple")
        #expect(stats.isConfigured == true)
    }

    @Test("validProfileURL with valid URL")
    func validProfileURLWithValidURL() {
        let stats = SocialAccountStats(
            slotID: "yt1",
            platform: .youtube,
            profileURL: "https://youtube.com/@testchannel"
        )
        #expect(stats.validProfileURL.absoluteString == "https://youtube.com/@testchannel")
    }

    @Test("validProfileURL falls back for each platform when empty")
    func validProfileURLFallbacks() {
        let ytStats = SocialAccountStats(slotID: "yt1", platform: .youtube, profileURL: "")
        #expect(ytStats.validProfileURL.absoluteString == "https://www.youtube.com")

        let igStats = SocialAccountStats(slotID: "ig1", platform: .instagram, profileURL: "")
        #expect(igStats.validProfileURL.absoluteString == "https://www.instagram.com")

        let ttStats = SocialAccountStats(slotID: "tt1", platform: .tiktok, profileURL: "")
        #expect(ttStats.validProfileURL.absoluteString == "https://www.tiktok.com")
    }

    @Test("validContentURL with content URL")
    func validContentURLWithValue() {
        let stats = SocialAccountStats(
            slotID: "yt1",
            platform: .youtube,
            profileURL: "https://youtube.com/@test",
            contentURL: "https://youtube.com/shorts/abc123"
        )
        #expect(stats.validContentURL.absoluteString == "https://youtube.com/shorts/abc123")
    }

    @Test("validContentURL falls back to profileURL")
    func validContentURLFallback() {
        let stats = SocialAccountStats(
            slotID: "yt1",
            platform: .youtube,
            profileURL: "https://youtube.com/@test",
            contentURL: nil
        )
        #expect(stats.validContentURL.absoluteString == "https://youtube.com/@test")
    }

    @Test("validContentURL falls back when contentURL is empty string")
    func validContentURLEmptyFallback() {
        let stats = SocialAccountStats(
            slotID: "yt1",
            platform: .youtube,
            profileURL: "https://youtube.com/@test",
            contentURL: ""
        )
        #expect(stats.validContentURL.absoluteString == "https://youtube.com/@test")
    }

    @Test("Default sample for YouTube")
    func defaultSampleYouTube() {
        let sample = SocialAccountStats.defaultSample(for: "youtube1", platform: .youtube)
        #expect(sample.slotID == "youtube1")
        #expect(sample.platform == SocialPlatform.youtube)
        #expect(sample.title == "YouTube Kanalı")
        #expect(sample.handle == "@kanal_ayarla")
        #expect(sample.mainStatCount == "--")
        #expect(sample.theme == "red")
        #expect(sample.isConfigured == false)
    }

    @Test("Default sample for Instagram")
    func defaultSampleInstagram() {
        let sample = SocialAccountStats.defaultSample(for: "instagram", platform: .instagram)
        #expect(sample.slotID == "instagram")
        #expect(sample.platform == SocialPlatform.instagram)
        #expect(sample.title == "Instagram Profili")
        #expect(sample.handle == "@kullanici_ayarla")
        #expect(sample.theme == "purple")
    }

    @Test("Default sample for TikTok")
    func defaultSampleTikTok() {
        let sample = SocialAccountStats.defaultSample(for: "tiktok", platform: .tiktok)
        #expect(sample.slotID == "tiktok")
        #expect(sample.platform == SocialPlatform.tiktok)
        #expect(sample.title == "TikTok Profili")
        #expect(sample.handle == "@kullanici_ayarla")
        #expect(sample.theme == "neon")
    }

    @Test("Equatable conformance")
    func equatable() {
        let stats1 = SocialAccountStats(slotID: "yt1", platform: .youtube, title: "Test", lastUpdated: Date(timeIntervalSince1970: 0))
        let stats2 = SocialAccountStats(slotID: "yt1", platform: .youtube, title: "Test", lastUpdated: Date(timeIntervalSince1970: 0))
        #expect(stats1 == stats2)

        var stats3 = stats1
        stats3.title = "Different"
        #expect(stats1 != stats3)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = SocialAccountStats(
            slotID: "youtube1",
            platform: .youtube,
            title: "Test Kanal",
            handle: "@test",
            mainStatCount: "2.76M abone",
            secondaryTitle: "Son Short",
            secondaryValue: "1K izlenme",
            avatarURL: "https://example.com/avatar.png",
            thumbnailURL: "https://example.com/thumb.png",
            profileURL: "https://youtube.com/@test",
            contentURL: "https://youtube.com/shorts/abc",
            theme: "dark",
            lastUpdated: Date(timeIntervalSince1970: 1700000000),
            isConfigured: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SocialAccountStats.self, from: data)

        #expect(original == decoded)
    }
}

// MARK: - YouTubeStats Tests
@Suite("YouTubeStats Tests")
struct YouTubeStatsTests {

    @Test("Default init values")
    func defaultInit() {
        let stats = YouTubeStats()
        #expect(stats.channelTitle == "YouTube Kanalı")
        #expect(stats.handle == "@kanal")
        #expect(stats.subscriberCount == "--")
        #expect(stats.avatarURL == nil)
        #expect(stats.latestShortTitle == "Son Short Henüz Yüklenmedi")
        #expect(stats.latestShortViews == "--")
        #expect(stats.latestShortThumbnail == nil)
        #expect(stats.latestShortURL == nil)
        #expect(stats.isConfigured == false)
    }

    @Test("Sample stats values")
    func sampleStats() {
        let sample = YouTubeStats.sample
        #expect(sample.channelTitle == "Örnek Kanal")
        #expect(sample.handle == "@ornekkanal")
        #expect(sample.subscriberCount == "125.4K")
        #expect(sample.isConfigured == true)
        #expect(sample.latestShortURL != nil)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = YouTubeStats(
            channelTitle: "Test Channel",
            handle: "@testchannel",
            subscriberCount: "500K",
            avatarURL: "https://example.com/avatar.jpg",
            latestShortTitle: "Cool Short",
            latestShortViews: "10K views",
            latestShortThumbnail: "https://example.com/thumb.jpg",
            latestShortURL: "https://youtube.com/shorts/abc",
            lastUpdated: Date(timeIntervalSince1970: 1700000000),
            isConfigured: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(YouTubeStats.self, from: data)

        #expect(original == decoded)
    }

    @Test("Equatable conformance")
    func equatable() {
        let date = Date(timeIntervalSince1970: 1000000)
        let stats1 = YouTubeStats(channelTitle: "A", handle: "@a", lastUpdated: date)
        let stats2 = YouTubeStats(channelTitle: "A", handle: "@a", lastUpdated: date)
        #expect(stats1 == stats2)

        var stats3 = stats1
        stats3.channelTitle = "B"
        #expect(stats1 != stats3)
    }
}

// MARK: - YouTubeService Tests
@Suite("YouTubeService Tests")
struct YouTubeServiceTests {

    @Test("Singleton returns same instance")
    func singleton() {
        let service1 = YouTubeService.shared
        let service2 = YouTubeService.shared
        #expect(service1 === service2, "Singleton instances should be the same object")
    }

    @Test("fetchStats throws for empty input")
    func fetchStatsEmptyInput() async {
        do {
            _ = try await YouTubeService.shared.fetchStats(channelInput: "")
            Issue.record("Should throw error for empty input")
        } catch {
            #expect(error is YouTubeError, "Expected YouTubeError but got \(type(of: error))")
            if let ytError = error as? YouTubeError {
                #expect(ytError.errorDescription != nil)
                #expect(ytError.errorDescription!.contains("girin"), "Error message should mention input")
            }
        }
    }

    @Test("fetchStats throws for whitespace-only input")
    func fetchStatsWhitespaceInput() async {
        do {
            _ = try await YouTubeService.shared.fetchStats(channelInput: "   \n\t  ")
            Issue.record("Should throw error for whitespace-only input")
        } catch {
            #expect(error is YouTubeError)
        }
    }

    @Test("Fresh instance can be created")
    func instantiation() {
        let service = YouTubeService()
        #expect(service !== YouTubeService.shared, "New instance should differ from singleton")
    }
}

// MARK: - YouTubeError Tests
@Suite("YouTubeError Tests")
struct YouTubeErrorTests {

    @Test("invalidInput error description")
    func invalidInput() {
        let error = YouTubeError.invalidInput("Test error message")
        #expect(error.errorDescription == "Test error message")
    }

    @Test("invalidURL error description")
    func invalidURL() {
        let error = YouTubeError.invalidURL("Bad URL")
        #expect(error.errorDescription == "Bad URL")
    }

    @Test("networkError description")
    func networkError() {
        let error = YouTubeError.networkError("Network down")
        #expect(error.errorDescription == "Network down")
    }

    @Test("parseError description")
    func parseError() {
        let error = YouTubeError.parseError("Parse failed")
        #expect(error.errorDescription == "Parse failed")
    }

    @Test("apiError description")
    func apiError() {
        let error = YouTubeError.apiError("API limit exceeded")
        #expect(error.errorDescription == "API limit exceeded")
    }

    @Test("Conforms to LocalizedError")
    func conformsToLocalizedError() {
        let error: LocalizedError = YouTubeError.invalidInput("test")
        #expect(error.errorDescription != nil)
    }
}

// MARK: - SocialService Tests
@Suite("SocialService Tests")
struct SocialServiceTests {

    @Test("Singleton returns same instance")
    func singleton() {
        let service1 = SocialService.shared
        let service2 = SocialService.shared
        #expect(service1 === service2)
    }

    @Test("fetchStats throws for empty input")
    func fetchStatsEmptyInput() async {
        do {
            _ = try await SocialService.shared.fetchStats(
                slotID: "test",
                platform: .youtube,
                input: ""
            )
            Issue.record("Should throw error for empty input")
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == "SocialService")
            #expect(nsError.code == 400)
        }
    }

    @Test("fetchStats throws for whitespace input")
    func fetchStatsWhitespaceInput() async {
        do {
            _ = try await SocialService.shared.fetchStats(
                slotID: "test",
                platform: .instagram,
                input: "   "
            )
            Issue.record("Should throw error for whitespace-only input")
        } catch {
            let nsError = error as NSError
            #expect(nsError.code == 400)
        }
    }
}

// MARK: - SharedDataManager Tests
@Suite("SharedDataManager Tests", .serialized)
struct SharedDataManagerTests {

    @Test("Singleton returns same instance")
    func singleton() {
        let manager1 = SharedDataManager.shared
        let manager2 = SharedDataManager.shared
        #expect(manager1 === manager2)
    }

    @Test("Save and load accounts roundtrip")
    func saveAndLoadAccounts() {
        let manager = SharedDataManager.shared
        let date = Date(timeIntervalSince1970: 1700000000)

        let testAccounts: [String: SocialAccountStats] = [
            "youtube1": SocialAccountStats(
                slotID: "youtube1",
                platform: .youtube,
                title: "Test Kanal",
                handle: "@testkanal",
                mainStatCount: "100K",
                profileURL: "https://youtube.com/@testkanal",
                theme: "red",
                lastUpdated: date,
                isConfigured: true
            ),
            "instagram": SocialAccountStats(
                slotID: "instagram",
                platform: .instagram,
                title: "Test IG",
                handle: "@testig",
                mainStatCount: "50K",
                profileURL: "https://instagram.com/testig",
                theme: "purple",
                lastUpdated: date,
                isConfigured: true
            )
        ]

        manager.saveAll(accounts: testAccounts, refreshIntervalMinutes: 360)

        let loaded = manager.loadAccounts()
        #expect(loaded != nil, "Loaded accounts should not be nil")

        if let loaded = loaded {
            #expect(loaded["youtube1"]?.title == "Test Kanal")
            #expect(loaded["youtube1"]?.handle == "@testkanal")
            #expect(loaded["youtube1"]?.mainStatCount == "100K")
            #expect(loaded["youtube1"]?.platform == SocialPlatform.youtube)
            #expect(loaded["instagram"]?.title == "Test IG")
            #expect(loaded["instagram"]?.handle == "@testig")
            #expect(loaded["instagram"]?.platform == SocialPlatform.instagram)
        }
    }

    @Test("Save and load refresh interval")
    func saveAndLoadRefreshInterval() {
        let manager = SharedDataManager.shared

        let accounts: [String: SocialAccountStats] = [
            "youtube1": SocialAccountStats(
                slotID: "youtube1",
                platform: .youtube,
                title: "Test",
                lastUpdated: Date(timeIntervalSince1970: 0)
            )
        ]

        manager.saveAll(accounts: accounts, refreshIntervalMinutes: 720)
        let loaded = manager.loadRefreshInterval()
        #expect(loaded == 720)
    }

    @Test("Refresh interval is always positive")
    func refreshIntervalPositive() {
        let interval = SharedDataManager.shared.loadRefreshInterval()
        #expect(interval > 0, "Refresh interval should be positive")
    }

    @Test("Legacy save method")
    func legacySave() {
        let manager = SharedDataManager.shared
        let stats = YouTubeStats(
            channelTitle: "Legacy Channel",
            handle: "@legacy",
            subscriberCount: "200K",
            lastUpdated: Date(timeIntervalSince1970: 1700000000),
            isConfigured: true
        )

        manager.save(stats: stats, channelInput: "@legacy", apiKey: nil, theme: "dark")

        let loaded = manager.loadAccounts()
        #expect(loaded != nil)
        #expect(loaded?["youtube1"]?.title == "Legacy Channel")
        #expect(loaded?["youtube1"]?.handle == "@legacy")
        #expect(loaded?["youtube1"]?.mainStatCount == "200K")
        #expect(loaded?["youtube1"]?.theme == "dark")
    }
}

// MARK: - MultiSocialWidgetConfig Tests
@Suite("MultiSocialWidgetConfig Tests")
struct MultiSocialWidgetConfigTests {

    @Test("Default init")
    func defaultInit() {
        let config = MultiSocialWidgetConfig()
        #expect(config.accounts.isEmpty)
        #expect(config.refreshIntervalMinutes == 360)
    }

    @Test("Custom init")
    func customInit() {
        let accounts: [String: SocialAccountStats] = [
            "youtube1": SocialAccountStats(slotID: "youtube1")
        ]
        let config = MultiSocialWidgetConfig(accounts: accounts, refreshIntervalMinutes: 720)
        #expect(config.accounts.count == 1)
        #expect(config.refreshIntervalMinutes == 720)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let accounts: [String: SocialAccountStats] = [
            "youtube1": SocialAccountStats(
                slotID: "youtube1",
                platform: .youtube,
                title: "Test",
                lastUpdated: Date(timeIntervalSince1970: 0)
            )
        ]
        let original = MultiSocialWidgetConfig(
            accounts: accounts,
            refreshIntervalMinutes: 120,
            lastSaved: Date(timeIntervalSince1970: 1700000000)
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MultiSocialWidgetConfig.self, from: data)

        #expect(decoded.refreshIntervalMinutes == 120)
        #expect(decoded.accounts.count == 1)
        #expect(decoded.accounts["youtube1"]?.title == "Test")
    }
}

// MARK: - WidgetSize Tests
@Suite("WidgetSize Tests")
struct WidgetSizeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(WidgetSize.small.rawValue == "small")
        #expect(WidgetSize.medium.rawValue == "medium")
    }

    @Test("Display names")
    func displayNames() {
        #expect(WidgetSize.small.displayName.contains("Küçük"))
        #expect(WidgetSize.medium.displayName.contains("Orta"))
    }

    @Test("Has 2 cases")
    func allCases() {
        #expect(WidgetSize.allCases.count == 2)
    }

    @Test("Codable roundtrip for all sizes")
    func codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for size in WidgetSize.allCases {
            let data = try encoder.encode(size)
            let decoded = try decoder.decode(WidgetSize.self, from: data)
            #expect(size == decoded)
        }
    }
}

// MARK: - Integration / Edge Case Tests
@Suite("Integration & Edge Case Tests")
struct IntegrationTests {

    @Test("Default samples for all platforms")
    func defaultSamplesAllPlatforms() {
        for platform in SocialPlatform.allCases {
            let sample = SocialAccountStats.defaultSample(for: platform.rawValue, platform: platform)
            #expect(sample.slotID == platform.rawValue)
            #expect(sample.platform == platform)
            #expect(sample.isConfigured == false, "Default samples should not be configured")
            #expect(sample.mainStatCount == "--", "Default stat count should be '--'")
            #expect(!sample.handle.isEmpty, "Default handle should not be empty")
        }
    }

    @Test("validProfileURL and validContentURL never crash with empty stats")
    func validURLsNeverCrash() {
        for platform in SocialPlatform.allCases {
            let emptyStats = SocialAccountStats(slotID: "empty", platform: platform)
            // These should never crash or return nil
            let profileURL = emptyStats.validProfileURL
            let contentURL = emptyStats.validContentURL
            #expect(profileURL.absoluteString.starts(with: "https://"), "Profile URL should be HTTPS for \(platform)")
            #expect(contentURL.absoluteString.starts(with: "https://"), "Content URL should be HTTPS for \(platform)")
        }
    }

    @Test("Multiple slot default samples don't conflict")
    func multipleSlotDefaults() {
        let yt1 = SocialAccountStats.defaultSample(for: "youtube1", platform: .youtube)
        let yt2 = SocialAccountStats.defaultSample(for: "youtube2", platform: .youtube)
        let ig = SocialAccountStats.defaultSample(for: "instagram", platform: .instagram)
        let tt = SocialAccountStats.defaultSample(for: "tiktok", platform: .tiktok)

        #expect(yt1.slotID != yt2.slotID)
        #expect(yt1.slotID != ig.slotID)
        #expect(ig.slotID != tt.slotID)

        // Same platform, different slots
        #expect(yt1.platform == yt2.platform)

        // Different platforms
        #expect(yt1.platform != ig.platform)
        #expect(ig.platform != tt.platform)
    }

    @Test("Profile URL with invalid URL string falls back correctly")
    func profileURLInvalidFallback() {
        let stats = SocialAccountStats(
            slotID: "test",
            platform: .youtube,
            profileURL: "not a valid url at all []{}"
        )
        let url = stats.validProfileURL
        // Should fall back to default YouTube URL since URL(string:) returns nil for invalid URLs
        #expect(url.absoluteString.contains("youtube"), "Should fall back to YouTube URL")
    }

    @Test("Sendable conformances compile")
    func sendableConformances() async {
        // Verify types can be used across concurrency boundaries
        let stats = SocialAccountStats(slotID: "test", lastUpdated: Date(timeIntervalSince1970: 0))
        let ytStats = YouTubeStats(lastUpdated: Date(timeIntervalSince1970: 0))
        let platform = SocialPlatform.youtube

        // These should all compile without warnings
        await Task.detached {
            _ = stats.slotID
            _ = ytStats.channelTitle
            _ = platform.displayName
        }.value
    }
}

// MARK: - UpdateChecker Tests
@Suite("UpdateChecker Tests")
struct UpdateCheckerTests {

    @Test("Semantic version comparison detects newer versions")
    func newerVersionDetection() {
        #expect(UpdateChecker.isVersion("v0.0.8", newerThan: "0.0.7"))
        #expect(UpdateChecker.isVersion("0.0.8", newerThan: "0.0.7"))
        #expect(UpdateChecker.isVersion("v0.1.0", newerThan: "0.0.7"))
        #expect(UpdateChecker.isVersion("v1.0.0", newerThan: "0.0.7"))
        #expect(UpdateChecker.isVersion("v0.0.10", newerThan: "0.0.9"))
        #expect(UpdateChecker.isVersion("1.0.0", newerThan: "0.9.9"))
    }

    @Test("Semantic version comparison detects older or equal versions")
    func olderOrEqualVersions() {
        #expect(!UpdateChecker.isVersion("v0.0.7", newerThan: "0.0.7"))
        #expect(!UpdateChecker.isVersion("0.0.7", newerThan: "0.0.7"))
        #expect(!UpdateChecker.isVersion("v0.0.6", newerThan: "0.0.7"))
        #expect(!UpdateChecker.isVersion("0.0.1", newerThan: "0.0.7"))
        #expect(!UpdateChecker.isVersion("0.0.7", newerThan: "v0.0.8"))
    }

    @Test("Normalize version strings")
    func normalizeVersions() {
        #expect(UpdateChecker.normalizeVersion("v0.0.8") == [0, 0, 8])
        #expect(UpdateChecker.normalizeVersion("V1.2.3") == [1, 2, 3])
        #expect(UpdateChecker.normalizeVersion("  v0.0.7-beta  ") == [0, 0, 7])
    }

    @Test("GitHubRelease JSON decoding")
    func decodeGitHubRelease() throws {
        let json = """
        {
            "tag_name": "v0.0.8",
            "name": "Finch v0.0.8",
            "body": "Yeni özellikler eklendi.",
            "html_url": "https://github.com/ufukcelen/Finch/releases/tag/v0.0.8",
            "published_at": "2026-10-29T10:00:00Z",
            "assets": [
                {
                    "name": "Finch-v0.0.8-macOS.zip",
                    "browser_download_url": "https://github.com/ufukcelen/Finch/releases/download/v0.0.8/Finch-v0.0.8-macOS.zip",
                    "size": 750000
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.tagName == "v0.0.8")
        #expect(release.name == "Finch v0.0.8")
        #expect(release.assets.count == 1)
        #expect(release.assets.first?.name == "Finch-v0.0.8-macOS.zip")
        #expect(release.assets.first?.browserDownloadURL.contains("Finch-v0.0.8-macOS.zip") == true)
    }
}
