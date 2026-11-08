import Foundation

// MARK: - Custom URLSession Delegate to block itms-apps:// redirects on iOS
private final class DesktopSafariRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Chặn chuyển hướng sang itms-apps:// hoặc itmss:// trên iPhone để lấy nguyên vẹn HTML
        if let scheme = request.url?.scheme?.lowercased(),
           scheme != "https" && scheme != "http" {
            completionHandler(nil)
            return
        }
        var modified = request
        modified.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        completionHandler(modified)
    }
}

// MARK: - AppStoreIAPService
@MainActor
final class AppStoreIAPService: ObservableObject {
    static let shared = AppStoreIAPService()

    private let session: URLSession
    private let redirectDelegate = DesktopSafariRedirectBlocker()
    private let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        config.httpAdditionalHeaders = [
            "User-Agent": desktopUserAgent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        self.session = URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)
    }

    // MARK: - 1. Tìm kiếm App (Theo từ khóa, Link App Store, App ID, hoặc Bundle ID)
    func searchApps(query: String, country: String = "vn") async throws -> [AppSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Kiểm tra nếu người dùng dán link App Store (vd: https://apps.apple.com/vn/app/.../id570060128)
        if let extractedId = extractAppId(from: trimmed) {
            if let app = try await lookupApp(byId: extractedId, country: country) {
                return [app]
            }
        }

        // Kiểm tra nếu người dùng nhập Bundle ID (vd: com.duolingo.Duolingo)
        if trimmed.contains(".") && !trimmed.contains(" ") && !trimmed.hasPrefix("http") {
            if let app = try await lookupApp(byBundleId: trimmed, country: country) {
                return [app]
            }
        }

        // Tìm kiếm theo từ khóa qua iTunes Search API
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results
    }

    func lookupApp(byId appId: Int, country: String = "vn") async throws -> AppSearchResult? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)&country=\(country)") else {
            return nil
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        if let first = decoded.results.first {
            return first
        }
        // Fallback sang US store nếu app không tìm thấy trên lookup vùng hiện tại
        if country != "us", let usUrl = URL(string: "https://itunes.apple.com/lookup?id=\(appId)&country=us") {
            let (usData, _) = try await URLSession.shared.data(from: usUrl)
            let usDecoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: usData)
            return usDecoded.results.first
        }
        return nil
    }

    func lookupApp(byBundleId bundleId: String, country: String = "vn") async throws -> AppSearchResult? {
        guard let encoded = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(encoded)&country=\(country)") else {
            return nil
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.first
    }

    private func extractAppId(from input: String) -> Int? {
        // Nếu chuỗi chỉ toàn số
        if let directId = Int(input), directId > 10000 {
            return directId
        }
        // Nếu chuỗi có dạng id123456789 trong link App Store
        let pattern = #"id(\d{6,15})"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: input) {
                return Int(input[idRange])
            }
        }
        return nil
    }

    // MARK: - 2. Quét danh sách IAP của 1 App tại 1 Quốc gia cụ thể
    func fetchIAPOffers(appId: Int, region: StorefrontRegion) async throws -> [IAPOfferItem] {
        await CurrencyService.shared.refreshRatesIfNeeded()

        struct RawCompanionPair {
            let title: String
            let price: String
            let sourceAppId: Int
            let sourceAppName: String?
            let customRegion: StorefrontRegion?
        }

        var rawList: [RawCompanionPair] = []

        // Gộp tự động hệ sinh thái Google (Google One + Gemini + Google App + Docs + Calendar) để lôi ra toàn bộ gói ẩn AI Pro (5TB), AI Ultra x5 (20TB), AI Ultra x20 (30TB), 30GB
        if appId == 1451784328 || appId == 6477489729 || appId == 284815942 {
            let companions: [(id: Int, name: String)] = [
                (6477489729, "Google Gemini"),
                (284815942, "Google App (Chứa AI Ultra x5 & x20)"),
                (1451784328, "Google One"),
                (842842640, "Google Docs (Chứa AI Pro 5TB Năm)"),
                (909319292, "Google Calendar")
            ]
            for comp in companions {
                if let pairs = try? await fetchSingleAppRawPairs(appId: comp.id, region: region) {
                    for p in pairs {
                        rawList.append(RawCompanionPair(title: p.title, price: p.price, sourceAppId: comp.id, sourceAppName: comp.name, customRegion: nil))
                    }
                }
            }
            // Nếu vùng hiện tại (như VN) ẩn gói AI Ultra x5 (20TB) và x20 (30TB) khỏi Top 10, tự động quét chéo sang TR để lôi ra
            if region.id != "tr", let trRegion = StorefrontRegion.supportedRegions.first(where: { $0.id == "tr" }) {
                if let trUltraPairs = try? await fetchSingleAppRawPairs(appId: 284815942, region: trRegion) {
                    let existingNames = Set(rawList.map { normalizeTitle($0.title, appId: appId).lowercased() })
                    for pair in trUltraPairs {
                        let norm = normalizeTitle(pair.title, appId: appId)
                        if !existingNames.contains(norm.lowercased()) {
                            rawList.append(RawCompanionPair(
                                title: norm,
                                price: pair.price,
                                sourceAppId: 284815942,
                                sourceAppName: "Google App • Mở ở Store 🇹🇷 TR",
                                customRegion: trRegion
                            ))
                        }
                    }
                }
            }
        } else if appId == 544007664 {
            let companions: [(id: Int, name: String)] = [
                (544007664, "YouTube"),
                (1017492454, "YouTube Music (Chứa Family 139k)")
            ]
            for comp in companions {
                if let pairs = try? await fetchSingleAppRawPairs(appId: comp.id, region: region) {
                    for p in pairs {
                        rawList.append(RawCompanionPair(title: p.title, price: p.price, sourceAppId: comp.id, sourceAppName: comp.name, customRegion: nil))
                    }
                }
            }
        } else {
            let pairs = try await fetchSingleAppRawPairs(appId: appId, region: region)
            for p in pairs {
                rawList.append(RawCompanionPair(title: p.title, price: p.price, sourceAppId: appId, sourceAppName: nil, customRegion: nil))
            }
        }

        var results: [IAPOfferItem] = []

        for (index, itemPair) in rawList.enumerated() {
            let effectiveRegion = itemPair.customRegion ?? region
            let normalizedTitle = normalizeTitle(itemPair.title, appId: itemPair.sourceAppId)
            let numeric = CurrencyService.shared.parseNumericPrice(from: itemPair.price, region: effectiveRegion)
            let vnd = CurrencyService.shared.convertToVND(numericPrice: numeric, region: effectiveRegion)
            let item = IAPOfferItem(
                title: normalizedTitle,
                rawPrice: itemPair.price,
                numericPrice: numeric,
                priceInVND: vnd,
                region: effectiveRegion,
                rankIndex: index + 1,
                sourceAppId: itemPair.sourceAppId,
                sourceAppName: itemPair.sourceAppName
            )
            results.append(item)
        }

        return results
    }

    private func fetchSingleAppRawPairs(appId: Int, region: StorefrontRegion) async throws -> [(title: String, price: String)] {
        guard let url = URL(string: "https://apps.apple.com/\(region.id)/app/id\(appId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return []
        }

        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }

        return extractTextPairsFromAppStoreHTML(html)
    }

    private func normalizeTitle(_ title: String, appId: Int) -> String {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("Google AI Ultra (20 TB)") && !t.contains("x5") {
            t = "Google AI Ultra x5 (20 TB)"
        } else if t.contains("Google AI Ultra (30 TB)") && !t.contains("x20") {
            t = "Google AI Ultra x20 (30 TB)"
        }
        if appId == 6473753684 {
            if t.contains("Claude Max") && !t.contains("x5") {
                t = t.replacingOccurrences(of: "Claude Max", with: "Claude Max (Gói x5)")
            } else if t.contains("Claude Ultra") && !t.contains("x20") {
                t = t.replacingOccurrences(of: "Claude Ultra", with: "Claude Ultra (Gói x20)")
            }
        }
        return t
    }

    // MARK: - 3. Quét song song tất cả 10 Quốc gia để so sánh giá & tìm gói ẩn rẻ nhất
    func scanMultiRegionIAPs(
        appId: Int,
        regions: [StorefrontRegion] = StorefrontRegion.supportedRegions
    ) async -> [RegionIAPScanResult] {
        await CurrencyService.shared.refreshRatesIfNeeded()

        return await withTaskGroup(of: RegionIAPScanResult.self) { group in
            for region in regions {
                group.addTask {
                    do {
                        let offers = try await self.fetchIAPOffers(appId: appId, region: region)
                        return RegionIAPScanResult(region: region, offers: offers, errorMessage: nil)
                    } catch {
                        return RegionIAPScanResult(
                            region: region,
                            offers: [],
                            errorMessage: error.localizedDescription
                        )
                    }
                }
            }

            var collected: [RegionIAPScanResult] = []
            for await res in group {
                collected.append(res)
            }

            // Sắp xếp ưu tiên vùng có gói IAP rẻ nhất (tính theo VNĐ) lên đầu
            return collected.sorted { a, b in
                let aMin = a.cheapestOffer?.priceInVND ?? .greatestFiniteMagnitude
                let bMin = b.cheapestOffer?.priceInVND ?? .greatestFiniteMagnitude
                if aMin != bMin {
                    return aMin < bMin
                }
                return a.region.id < b.region.id
            }
        }
    }

    // MARK: - 4. Gom nhóm các gói IAP trùng tên để phát hiện các mức giá ẩn (A/B Testing Tiers)
    func groupOffersByTitle(_ offers: [IAPOfferItem]) -> [IAPOfferGroup] {
        var dict: [String: [IAPOfferItem]] = [:]
        var displayTitles: [String: String] = [:]

        for offer in offers {
            let normalizedKey = offer.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            dict[normalizedKey, default: []].append(offer)
            if displayTitles[normalizedKey] == nil {
                displayTitles[normalizedKey] = offer.title
            }
        }

        var groups: [IAPOfferGroup] = []
        for (key, items) in dict {
            let sortedItems = items.sorted {
                ($0.priceInVND ?? .greatestFiniteMagnitude) < ($1.priceInVND ?? .greatestFiniteMagnitude)
            }
            let group = IAPOfferGroup(
                id: key,
                title: displayTitles[key] ?? items.first?.title ?? "Gói IAP",
                offers: sortedItems
            )
            groups.append(group)
        }

        // Ưu tiên hiển thị các nhóm có nhiều mức giá ẩn (hasHiddenPriceTiers) lên trước
        return groups.sorted { a, b in
            if a.hasHiddenPriceTiers != b.hasHiddenPriceTiers {
                return a.hasHiddenPriceTiers && !b.hasHiddenPriceTiers
            }
            let aMin = a.cheapestOffer?.priceInVND ?? .greatestFiniteMagnitude
            let bMin = b.cheapestOffer?.priceInVND ?? .greatestFiniteMagnitude
            return aMin < bMin
        }
    }

    // MARK: - Internal Parser cho `<script id="serialized-server-data">` của App Store
    private nonisolated func extractTextPairsFromAppStoreHTML(_ html: String) -> [(title: String, price: String)] {
        let pattern = #"<script[^>]*id="serialized-server-data"[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: nsRange),
              let jsonRange = Range(match.range(at: 1), in: html) else {
            return []
        }

        let jsonString = String(html[jsonRange])
        guard let jsonData = jsonString.data(using: .utf8),
              let rootObj = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            return []
        }

        var pairs: [(title: String, price: String)] = []
        collectTextPairsRecursively(from: rootObj, into: &pairs)
        return pairs
    }

    private nonisolated func collectTextPairsRecursively(
        from node: Any,
        into results: inout [(title: String, price: String)]
    ) {
        if let dict = node as? [String: Any] {
            if let kind = dict["$kind"] as? String,
               kind == "textPair",
               let leading = dict["leadingText"] as? String,
               let trailing = dict["trailingText"] as? String,
               !leading.isEmpty,
               !trailing.isEmpty {
                results.append((title: leading, price: trailing))
                return
            }
            for (_, value) in dict {
                collectTextPairsRecursively(from: value, into: &results)
            }
        } else if let array = node as? [Any] {
            for element in array {
                collectTextPairsRecursively(from: element, into: &results)
            }
        }
    }
}
