import Foundation

public final class YouTubeService: @unchecked Sendable {
    public static let shared = YouTubeService()

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    /// Fetches YouTube channel info and latest short stats
    public func fetchStats(channelInput: String, apiKey: String? = nil) async throws -> YouTubeStats {
        let trimmed = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "Girdi boş.")
            throw YouTubeError.invalidInput("Lütfen bir YouTube kanal adı veya bağlantısı girin.")
        }

        DebugLogger.shared.log(.info, tag: "YouTubeService", message: "Kanal aranıyor: '\(trimmed)'")

        // If API key is provided and non-empty, use YouTube Data API v3
        if let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            DebugLogger.shared.log(.info, tag: "YouTubeService", message: "API v3 anahtarı ile sorgulanıyor.")
            return try await fetchViaAPI(channelInput: trimmed, apiKey: key)
        }

        // Otherwise use direct public fetching
        DebugLogger.shared.log(.info, tag: "YouTubeService", message: "Doğrudan web kazıma ile sorgulanıyor.")
        return try await fetchViaPublicData(channelInput: trimmed)
    }

    // MARK: - Direct Public Data Fetcher (No API Key Required)
    private func fetchViaPublicData(channelInput: String) async throws -> YouTubeStats {
        let (channelURL, handleDisplay) = resolveChannelShortsURL(from: channelInput)
        
        guard let url = URL(string: channelURL) else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "Geçersiz URL: \(channelURL)")
            throw YouTubeError.invalidURL("Geçersiz YouTube URL adresi: \(channelURL)")
        }

        DebugLogger.shared.log(.debug, tag: "YouTubeService", message: "İstek atılıyor: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "HTTP yanıt kodu hatası: \(code)")
            throw YouTubeError.networkError("YouTube sayfasına ulaşılamadı (HTTP \(code)). Lütfen kanal adını kontrol edin.")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "HTML verisi utf8 olarak çözülemedi.")
            throw YouTubeError.parseError("YouTube içeriği okunamadı.")
        }

        DebugLogger.shared.log(.debug, tag: "YouTubeService", message: "HTML alındı, boyut: \(html.count) bayt. Ayrıştırılıyor...")
        return try parsePublicHTML(html: html, fallbackHandle: handleDisplay)
    }

    private func parsePublicHTML(html: String, fallbackHandle: String) throws -> YouTubeStats {
        // Look for ytInitialData in HTML with multiple possible markers
        let markers = ["ytInitialData = ", "ytInitialData=", "var ytInitialData = ", "window[\"ytInitialData\"] = "]
        var matchRange: Range<String.Index>? = nil
        for marker in markers {
            if let range = html.range(of: marker) {
                matchRange = range
                break
            }
        }

        guard let matchRange = matchRange else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "ytInitialData bulunamadı.")
            throw YouTubeError.parseError("YouTube verisi bulunamadı. Kanal gizli veya mevcut olmayabilir.")
        }

        let afterData = html[matchRange.upperBound...]
        guard let endRange = afterData.range(of: ";</script>") ?? afterData.range(of: ";var ") ?? afterData.range(of: ";</") else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "JSON sonlanma karakteri bulunamadı.")
            throw YouTubeError.parseError("Kanal veri sonu ayrıştırılamadı.")
        }

        let jsonString = String(afterData[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            DebugLogger.shared.log(.error, tag: "YouTubeService", message: "JSON ayrıştırma hatası.")
            throw YouTubeError.parseError("Kanal verisi JSON formatında okunamadı.")
        }

        var stats = YouTubeStats()
        stats.handle = fallbackHandle
        stats.isConfigured = true
        stats.lastUpdated = Date()

        // Extract Header (Channel Title, Avatar, Subscriber Count)
        extractHeaderData(from: json, stats: &stats)

        // Extract Latest Short Video (Title, View Count, Thumbnail, URL)
        extractLatestShortData(from: json, stats: &stats)

        // Fallbacks if title is empty
        if stats.channelTitle.isEmpty || stats.channelTitle == "YouTube Kanalı" {
            if let titleRange = html.range(of: "<title>") {
                let after = html[titleRange.upperBound...]
                if let endTitle = after.range(of: " - YouTube</title>") ?? after.range(of: "</title>") {
                    let pageTitle = String(after[..<endTitle.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !pageTitle.isEmpty {
                        stats.channelTitle = pageTitle
                    }
                }
            }
        }

        DebugLogger.shared.log(.info, tag: "YouTubeService", message: "Başarıyla ayrıştırıldı: '\(stats.channelTitle)', Abone: '\(stats.subscriberCount)', Short: '\(stats.latestShortTitle)'")
        return stats
    }

    private func extractHeaderData(from json: [String: Any], stats: inout YouTubeStats) {
        if let header = json["header"] as? [String: Any],
           let pageHeader = header["pageHeaderRenderer"] as? [String: Any],
           let content = pageHeader["content"] as? [String: Any],
           let vm = content["pageHeaderViewModel"] as? [String: Any] {

            // Channel Title
            if let titleObj = vm["title"] as? [String: Any],
               let dyn = titleObj["dynamicTextViewModel"] as? [String: Any],
               let text = dyn["text"] as? [String: Any],
               let titleStr = text["content"] as? String {
                stats.channelTitle = titleStr
            }

            // Subscriber Count & Handle from metadata
            if let metadata = vm["metadata"] as? [String: Any],
               let rows = metadata["contentMetadataViewModel"] as? [String: Any],
               let metaRows = rows["metadataRows"] as? [[String: Any]] {
                for row in metaRows {
                    if let parts = row["metadataParts"] as? [[String: Any]] {
                        for part in parts {
                            if let textObj = part["text"] as? [String: Any],
                               let partText = textObj["content"] as? String {
                                if partText.starts(with: "@") {
                                    stats.handle = partText
                                } else if partText.contains("abone") || partText.lowercased().contains("sub") {
                                    stats.subscriberCount = cleanStatCount(partText)
                                }
                            }
                        }
                    }
                }
            }

            // Avatar URL
            if let imageObj = vm["image"] as? [String: Any],
               let decorated = imageObj["decoratedAvatarViewModel"] as? [String: Any],
               let avatar = decorated["avatar"] as? [String: Any],
               let avatarVM = avatar["avatarViewModel"] as? [String: Any],
               let image = avatarVM["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]],
               let lastOrFirst = sources.last ?? sources.first,
               let urlStr = lastOrFirst["url"] as? String {
                stats.avatarURL = urlStr
            }
        } else if let header = json["header"] as? [String: Any],
                  let c4Header = header["c4TabbedHeaderRenderer"] as? [String: Any] {
            // Older YouTube header fallback
            if let title = c4Header["title"] as? String {
                stats.channelTitle = title
            }
            if let subObj = c4Header["subscriberCountText"] as? [String: Any],
               let simpleText = subObj["simpleText"] as? String {
                stats.subscriberCount = cleanStatCount(simpleText)
            }
            if let avatar = c4Header["avatar"] as? [String: Any],
               let thumbs = avatar["thumbnails"] as? [[String: Any]],
               let urlStr = thumbs.last?["url"] as? String {
                stats.avatarURL = urlStr
            }
        }
    }

    private func extractLatestShortData(from json: [String: Any], stats: inout YouTubeStats) {
        func recursiveFind(key: String, in obj: Any) -> [[String: Any]] {
            var items = [[String: Any]]()
            if let dict = obj as? [String: Any] {
                if let target = dict[key] as? [String: Any] {
                    items.append(target)
                }
                for v in dict.values {
                    items.append(contentsOf: recursiveFind(key: key, in: v))
                }
            } else if let array = obj as? [Any] {
                for item in array {
                    items.append(contentsOf: recursiveFind(key: key, in: item))
                }
            }
            return items
        }

        let shortsLockups = recursiveFind(key: "shortsLockupViewModel", in: json)
        if let latest = shortsLockups.first {
            // Primary text is title
            if let overlay = latest["overlayMetadata"] as? [String: Any] {
                if let primary = overlay["primaryText"] as? [String: Any],
                   let title = primary["content"] as? String {
                    stats.latestShortTitle = title
                }
                if let secondary = overlay["secondaryText"] as? [String: Any],
                   let views = secondary["content"] as? String {
                    stats.latestShortViews = views
                }
            }

            // Thumbnail
            if let thumbVM = latest["thumbnailViewModel"] as? [String: Any],
               let innerThumb = thumbVM["thumbnailViewModel"] as? [String: Any],
               let image = innerThumb["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]],
               let bestSource = sources.last ?? sources.first,
               let urlStr = bestSource["url"] as? String {
                stats.latestShortThumbnail = urlStr
            }

            // Video ID & URL
            if let entityId = latest["entityId"] as? String {
                let prefix = "shorts-shelf-item-"
                if entityId.hasPrefix(prefix) {
                    let videoId = String(entityId.dropFirst(prefix.count))
                    stats.latestShortURL = "https://www.youtube.com/shorts/\(videoId)"
                }
            }
        }
    }

    private func resolveChannelShortsURL(from input: String) -> (url: String, displayHandle: String) {
        var clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while clean.hasSuffix("/") {
            clean.removeLast()
        }

        if clean.lowercased().hasPrefix("http://") || clean.lowercased().hasPrefix("https://") {
            if clean.contains("/shorts") {
                return (clean, extractHandleOrPath(from: clean))
            } else {
                return ("\(clean)/shorts", extractHandleOrPath(from: clean))
            }
        }

        if clean.starts(with: "UC") && clean.count == 24 {
            return ("https://www.youtube.com/channel/\(clean)/shorts", clean)
        }

        let handle = clean.starts(with: "@") ? clean : "@\(clean)"
        return ("https://www.youtube.com/\(handle)/shorts", handle)
    }

    private func extractHandleOrPath(from urlStr: String) -> String {
        guard let url = URL(string: urlStr) else { return "@kanal" }
        let components = url.pathComponents.filter { $0 != "/" && $0 != "shorts" }
        return components.last ?? "@kanal"
    }

    // MARK: - Official YouTube Data API v3 Fetcher (Optional)
    private func fetchViaAPI(channelInput: String, apiKey: String) async throws -> YouTubeStats {
        var stats = YouTubeStats()
        stats.isConfigured = true
        stats.lastUpdated = Date()

        let clean = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChannelId = clean.starts(with: "UC") && clean.count == 24
        let handle = clean.starts(with: "@") ? String(clean.dropFirst()) : clean

        let channelEndpoint: String
        if isChannelId {
            channelEndpoint = "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,contentDetails&id=\(clean)&key=\(apiKey)"
        } else {
            channelEndpoint = "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,contentDetails&forHandle=\(handle)&key=\(apiKey)"
        }

        guard let channelURL = URL(string: channelEndpoint) else {
            throw YouTubeError.invalidURL("API URL oluşturulamadı.")
        }

        let (chanData, _) = try await session.data(from: channelURL)
        guard let chanJSON = try? JSONSerialization.jsonObject(with: chanData) as? [String: Any],
              let items = chanJSON["items"] as? [[String: Any]],
              let firstChan = items.first else {
            throw YouTubeError.apiError("Kanal bilgileri YouTube API ile bulunamadı.")
        }

        if let snippet = firstChan["snippet"] as? [String: Any] {
            stats.channelTitle = snippet["title"] as? String ?? "YouTube Kanalı"
            stats.handle = snippet["customUrl"] as? String ?? "@\(handle)"
            if let thumbs = snippet["thumbnails"] as? [String: Any],
               let high = thumbs["high"] as? [String: Any] ?? thumbs["default"] as? [String: Any],
               let url = high["url"] as? String {
                stats.avatarURL = url
            }
        }

        if let statistics = firstChan["statistics"] as? [String: Any] {
            if let countStr = statistics["subscriberCount"] as? String, let count = Int(countStr) {
                stats.subscriberCount = formatNumber(count)
            }
        }

        if let contentDetails = firstChan["contentDetails"] as? [String: Any],
           let relatedPlaylists = contentDetails["relatedPlaylists"] as? [String: Any],
           let uploadsId = relatedPlaylists["uploads"] as? String {

            let playlistEndpoint = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=\(uploadsId)&maxResults=5&key=\(apiKey)"
            if let pURL = URL(string: playlistEndpoint),
               let (pData, _) = try? await session.data(from: pURL),
               let pJSON = try? JSONSerialization.jsonObject(with: pData) as? [String: Any],
               let vItems = pJSON["items"] as? [[String: Any]],
               let firstVideo = vItems.first,
               let vSnippet = firstVideo["snippet"] as? [String: Any],
               let resourceId = vSnippet["resourceId"] as? [String: Any],
               let videoId = resourceId["videoId"] as? String {

                stats.latestShortTitle = vSnippet["title"] as? String ?? ""
                stats.latestShortURL = "https://www.youtube.com/shorts/\(videoId)"

                if let vThumbs = vSnippet["thumbnails"] as? [String: Any],
                   let high = vThumbs["high"] as? [String: Any] ?? vThumbs["medium"] as? [String: Any],
                   let url = high["url"] as? String {
                    stats.latestShortThumbnail = url
                }

                let videoEndpoint = "https://www.googleapis.com/youtube/v3/videos?part=statistics&id=\(videoId)&key=\(apiKey)"
                if let vURL = URL(string: videoEndpoint),
                   let (vidData, _) = try? await session.data(from: vURL),
                   let vidJSON = try? JSONSerialization.jsonObject(with: vidData) as? [String: Any],
                   let vidItems = vidJSON["items"] as? [[String: Any]],
                   let vidFirst = vidItems.first,
                   let vidStats = vidFirst["statistics"] as? [String: Any],
                   let viewStr = vidStats["viewCount"] as? String,
                   let views = Int(viewStr) {
                    stats.latestShortViews = formatNumber(views) + " izlenme"
                }
            }
        }

        return stats
    }

    private func cleanStatCount(_ text: String) -> String {
        // Strip common redundant suffixes while preserving numeric values like "2,76 B", "6.63M"
        var clean = text
        let suffixes = [" abone", " aboneleri", " subscribers", " subscriber", " subs"]
        for s in suffixes {
            if clean.localizedCaseInsensitiveContains(s) {
                if let r = clean.range(of: s, options: .caseInsensitive) {
                    clean.removeSubrange(r)
                }
            }
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            let m = Double(num) / 1_000_000.0
            return String(format: "%.1fM", m).replacingOccurrences(of: ".0", with: "")
        } else if num >= 1_000 {
            let k = Double(num) / 1_000.0
            return String(format: "%.1fK", k).replacingOccurrences(of: ".0", with: "")
        } else {
            return "\(num)"
        }
    }
}

public enum YouTubeError: LocalizedError {
    case invalidInput(String)
    case invalidURL(String)
    case networkError(String)
    case parseError(String)
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg),
             .invalidURL(let msg),
             .networkError(let msg),
             .parseError(let msg),
             .apiError(let msg):
            return msg
        }
    }
}
