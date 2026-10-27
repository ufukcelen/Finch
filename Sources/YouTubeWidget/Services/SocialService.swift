import Foundation

public final class SocialService: Sendable {
    public static let shared = SocialService()

    private let socialUserAgent = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"

    private init() {}

    public func fetchStats(
        slotID: String,
        platform: SocialPlatform,
        input: String,
        apiKey: String? = nil,
        theme: String = "red"
    ) async throws -> SocialAccountStats {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw NSError(domain: "SocialService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı adı veya kanal boş olamaz."])
        }

        switch platform {
        case .youtube:
            return try await fetchYouTube(slotID: slotID, input: clean, apiKey: apiKey, theme: theme)
        case .instagram:
            return try await fetchInstagram(slotID: slotID, input: clean, theme: theme)
        case .tiktok:
            return try await fetchTikTok(slotID: slotID, input: clean, theme: theme)
        }
    }

    // MARK: - YouTube
    private func fetchYouTube(slotID: String, input: String, apiKey: String?, theme: String) async throws -> SocialAccountStats {
        let yt = try await YouTubeService.shared.fetchStats(channelInput: input, apiKey: apiKey)
        var profileURL = "https://www.youtube.com"
        if yt.handle.starts(with: "@") {
            profileURL = "https://www.youtube.com/\(yt.handle)"
        } else if input.lowercased().starts(with: "http") {
            profileURL = input
        }

        return SocialAccountStats(
            slotID: slotID,
            platform: .youtube,
            title: yt.channelTitle,
            handle: yt.handle,
            mainStatCount: yt.subscriberCount,
            secondaryTitle: yt.latestShortTitle,
            secondaryValue: yt.latestShortViews,
            avatarURL: yt.avatarURL,
            thumbnailURL: yt.latestShortThumbnail,
            profileURL: profileURL,
            contentURL: yt.latestShortURL,
            theme: theme.isEmpty ? "red" : theme,
            lastUpdated: Date(),
            isConfigured: true
        )
    }

    // MARK: - Instagram
    private func fetchInstagram(slotID: String, input: String, theme: String) async throws -> SocialAccountStats {
        let cleanUser = input.trimmingCharacters(in: CharacterSet(charactersIn: "@ /")).components(separatedBy: "/").last ?? input
        guard let url = URL(string: "https://www.instagram.com/\(cleanUser)/") else {
            throw NSError(domain: "SocialService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz Instagram kullanıcı adı."])
        }

        var request = URLRequest(url: url)
        request.setValue(socialUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SocialService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Instagram profili bulunamadı veya gizli."])
        }

        var followers = "--"
        var posts = "--"
        var title = cleanUser
        let handle = "@\(cleanUser)"
        var avatarURL: String? = nil

        if let desc = extractMetaContent(html: html, property: "og:description") {
            let decoded = decodeHTMLEntities(desc)
            if let f = matchRegexGroup(text: decoded, pattern: "([0-9.,]+[KkMmBb]?)\\s*(?:followers|takipçi|takip)") {
                followers = f
            }
            if let p = matchRegexGroup(text: decoded, pattern: "([0-9.,]+[KkMmBb]?)\\s*(?:posts|gönderi)") {
                posts = "\(p) Gönderi"
            }
        }

        if let rawTitle = extractMetaContent(html: html, property: "og:title") {
            var cleanTitle = decodeHTMLEntities(rawTitle)
            if let sep = cleanTitle.range(of: " (") {
                cleanTitle = String(cleanTitle[..<sep.lowerBound])
            }
            if let sep = cleanTitle.range(of: " •") {
                cleanTitle = String(cleanTitle[..<sep.lowerBound])
            }
            title = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let img = extractMetaContent(html: html, property: "og:image") {
            avatarURL = decodeHTMLEntities(img)
        }

        guard followers != "--" else {
            throw NSError(domain: "SocialService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Instagram takipçi bilgisi alınamadı. Kullanıcı adı doğru mu?"])
        }

        return SocialAccountStats(
            slotID: slotID,
            platform: .instagram,
            title: title.isEmpty ? cleanUser : title,
            handle: handle,
            mainStatCount: followers,
            secondaryTitle: "\(title) - Instagram",
            secondaryValue: posts == "--" ? "Instagram" : posts,
            avatarURL: avatarURL,
            thumbnailURL: nil,
            profileURL: "https://www.instagram.com/\(cleanUser)/",
            contentURL: "https://www.instagram.com/\(cleanUser)/",
            theme: theme.isEmpty ? "purple" : theme,
            lastUpdated: Date(),
            isConfigured: true
        )
    }

    // MARK: - TikTok
    private func fetchTikTok(slotID: String, input: String, theme: String) async throws -> SocialAccountStats {
        let cleanUser = input.trimmingCharacters(in: CharacterSet(charactersIn: "@ /")).components(separatedBy: "/").last ?? input
        guard let url = URL(string: "https://www.tiktok.com/@\(cleanUser)") else {
            throw NSError(domain: "SocialService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz TikTok kullanıcı adı."])
        }

        var request = URLRequest(url: url)
        request.setValue(socialUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SocialService", code: 404, userInfo: [NSLocalizedDescriptionKey: "TikTok profili bulunamadı veya gizli."])
        }

        var followers = "--"
        var likes = "--"
        var title = cleanUser
        let handle = "@\(cleanUser)"
        var avatarURL: String? = nil

        if let desc = extractMetaContent(html: html, property: "og:description") {
            let decoded = decodeHTMLEntities(desc)
            if let f = matchRegexGroup(text: decoded, pattern: "([0-9.,]+[KkMmBb]?)\\s*(?:followers|takipçi)") {
                followers = f
            }
            if let l = matchRegexGroup(text: decoded, pattern: "([0-9.,]+[KkMmBb]?)\\s*(?:likes|beğeni)") {
                likes = "\(l) Beğeni"
            }
        }

        if let rawTitle = extractMetaContent(html: html, property: "og:title") {
            var cleanTitle = decodeHTMLEntities(rawTitle)
            if let sep = cleanTitle.range(of: " on TikTok") {
                cleanTitle = String(cleanTitle[..<sep.lowerBound])
            }
            if let sep = cleanTitle.range(of: " TikTok'ta") {
                cleanTitle = String(cleanTitle[..<sep.lowerBound])
            }
            title = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let img = extractMetaContent(html: html, property: "og:image") {
            avatarURL = decodeHTMLEntities(img)
        }

        guard followers != "--" else {
            throw NSError(domain: "SocialService", code: 422, userInfo: [NSLocalizedDescriptionKey: "TikTok takipçi bilgisi alınamadı. Kullanıcı adı doğru mu?"])
        }

        return SocialAccountStats(
            slotID: slotID,
            platform: .tiktok,
            title: title.isEmpty ? cleanUser : title,
            handle: handle,
            mainStatCount: followers,
            secondaryTitle: "\(title) TikTok",
            secondaryValue: likes == "--" ? "TikTok" : likes,
            avatarURL: avatarURL,
            thumbnailURL: nil,
            profileURL: "https://www.tiktok.com/@\(cleanUser)",
            contentURL: "https://www.tiktok.com/@\(cleanUser)",
            theme: theme.isEmpty ? "neon" : theme,
            lastUpdated: Date(),
            isConfigured: true
        )
    }

    // MARK: - HTML Extraction Helpers
    private func extractMetaContent(html: String, property: String) -> String? {
        let pattern1 = "<meta\\s+property=[\"']\(property)[\"']\\s+content=[\"']([^\"']+)[\"']"
        if let val = matchRegexGroup(text: html, pattern: pattern1) {
            return val
        }
        let pattern2 = "<meta\\s+content=[\"']([^\"']+)[\"']\\s+property=[\"']\(property)[\"']"
        return matchRegexGroup(text: html, pattern: pattern2)
    }

    private func matchRegexGroup(text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsString = text as NSString
        if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
           match.numberOfRanges > 1 {
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var s = string
        s = s.replacingOccurrences(of: "&#xe7;", with: "ç")
        s = s.replacingOccurrences(of: "&#xc7;", with: "Ç")
        s = s.replacingOccurrences(of: "&#xf6;", with: "ö")
        s = s.replacingOccurrences(of: "&#xd6;", with: "Ö")
        s = s.replacingOccurrences(of: "&#x131;", with: "ı")
        s = s.replacingOccurrences(of: "&#x130;", with: "İ")
        s = s.replacingOccurrences(of: "&#x15f;", with: "ş")
        s = s.replacingOccurrences(of: "&#x15e;", with: "Ş")
        s = s.replacingOccurrences(of: "&#x11f;", with: "ğ")
        s = s.replacingOccurrences(of: "&#x11e;", with: "Ğ")
        s = s.replacingOccurrences(of: "&#064;", with: "@")
        s = s.replacingOccurrences(of: "&#039;", with: "'")
        s = s.replacingOccurrences(of: "&#27;", with: "'")
        s = s.replacingOccurrences(of: "&#x27;", with: "'")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        return s
    }
}
