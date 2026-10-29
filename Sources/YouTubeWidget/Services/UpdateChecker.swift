import Foundation
import AppKit

public struct GitHubRelease: Codable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: String
    public let publishedAt: String?
    public let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

public struct GitHubReleaseAsset: Codable, Sendable {
    public let name: String
    public let browserDownloadURL: String
    public let size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var updateAvailable: Bool = false
    @Published public private(set) var latestRelease: GitHubRelease?
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var errorMessage: String?
    @Published public var showReleaseNotesSheet: Bool = false

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.7"
    }

    public var latestVersion: String {
        latestRelease?.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")) ?? ""
    }

    public var downloadURL: URL? {
        if let asset = latestRelease?.assets.first(where: { $0.name.hasSuffix(".zip") }) {
            return URL(string: asset.browserDownloadURL)
        }
        if let html = latestRelease?.htmlURL {
            return URL(string: html)
        }
        return nil
    }

    public var releasePageURL: URL? {
        if let html = latestRelease?.htmlURL {
            return URL(string: html)
        }
        return URL(string: "https://github.com/ufukcelen/Finch/releases")
    }

    public var releaseNotes: String {
        latestRelease?.body ?? "Bu sürüm için açıklama eklenmedi."
    }

    private let repoURL = "https://api.github.com/repos/ufukcelen/Finch/releases/latest"

    public func checkForUpdates(manual: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        defer {
            isChecking = false
            lastChecked = Date()
        }

        guard let url = URL(string: repoURL) else {
            errorMessage = "Geçersiz güncelleme URL adresi."
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Finch-macOS-Widget", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Sunucu yanıt vermedi."
                return
            }

            if http.statusCode == 404 {
                // Henüz release yoksa
                DebugLogger.shared.log(.info, tag: "UpdateChecker", message: "Henüz bir release bulunamadı.")
                updateAvailable = false
                return
            }

            guard (200...299).contains(http.statusCode) else {
                errorMessage = "GitHub API hatası (HTTP \(http.statusCode))."
                DebugLogger.shared.log(.error, tag: "UpdateChecker", message: "HTTP \(http.statusCode)")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            self.latestRelease = release

            let isNewer = Self.isVersion(release.tagName, newerThan: currentVersion)
            self.updateAvailable = isNewer

            DebugLogger.shared.log(.info, tag: "UpdateChecker", message: "Son sürüm: \(release.tagName), Mevcut: \(currentVersion), Güncelleme: \(isNewer)")
        } catch {
            errorMessage = "Güncelleme denetlenemedi."
            DebugLogger.shared.log(.error, tag: "UpdateChecker", message: "Hata: \(error.localizedDescription)")
        }
    }

    /// Semantic version comparison: returns true if candidate is newer than current.
    nonisolated public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let cParts = normalizeVersion(candidate)
        let curParts = normalizeVersion(current)

        let maxCount = max(cParts.count, curParts.count)
        for i in 0..<maxCount {
            let c = i < cParts.count ? cParts[i] : 0
            let cur = i < curParts.count ? curParts[i] : 0
            if c > cur { return true }
            if c < cur { return false }
        }
        return false
    }

    nonisolated public static func normalizeVersion(_ v: String) -> [Int] {
        let clean = v.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        return clean.split(separator: ".").compactMap { part in
            Int(part.prefix(while: { $0.isNumber }))
        }
    }

    public func openDownloadOrReleasePage() {
        if let url = downloadURL {
            NSWorkspace.shared.open(url)
        }
    }
}
