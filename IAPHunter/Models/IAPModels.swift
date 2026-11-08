import Foundation

// MARK: - Storefront / Country Region Model
struct StorefrontRegion: Identifiable, Hashable, Codable {
    let id: String          // ISO country code lowercase, e.g. "vn", "tr", "ng"
    let name: String        // Tên quốc gia tiếng Việt
    let flag: String        // Emoji cờ
    let currencyCode: String // Mã tiền tệ ISO, e.g. "VND", "TRY", "NGN"
    let decimalSeparator: String // Dấu phân cách thập phân chuẩn trên App Store của vùng đó
    let hasDecimals: Bool   // Tiền tệ có phần thập phân trên App Store hay không

    static let supportedRegions: [StorefrontRegion] = [
        StorefrontRegion(id: "vn", name: "Việt Nam", flag: "🇻🇳", currencyCode: "VND", decimalSeparator: ",", hasDecimals: false),
        StorefrontRegion(id: "tr", name: "Thổ Nhĩ Kỳ", flag: "🇹🇷", currencyCode: "TRY", decimalSeparator: ",", hasDecimals: true),
        StorefrontRegion(id: "ng", name: "Nigeria", flag: "🇳🇬", currencyCode: "NGN", decimalSeparator: ".", hasDecimals: true),
        StorefrontRegion(id: "eg", name: "Ai Cập", flag: "🇪🇬", currencyCode: "EGP", decimalSeparator: ".", hasDecimals: true),
        StorefrontRegion(id: "in", name: "Ấn Độ", flag: "🇮🇳", currencyCode: "INR", decimalSeparator: ".", hasDecimals: true),
        StorefrontRegion(id: "pk", name: "Pakistan", flag: "🇵🇰", currencyCode: "PKR", decimalSeparator: ".", hasDecimals: true),
        StorefrontRegion(id: "br", name: "Brazil", flag: "🇧🇷", currencyCode: "BRL", decimalSeparator: ",", hasDecimals: true),
        StorefrontRegion(id: "id", name: "Indonesia", flag: "🇮🇩", currencyCode: "IDR", decimalSeparator: ",", hasDecimals: false),
        StorefrontRegion(id: "ph", name: "Philippines", flag: "🇵🇭", currencyCode: "PHP", decimalSeparator: ".", hasDecimals: true),
        StorefrontRegion(id: "us", name: "Mỹ (US)", flag: "🇺🇸", currencyCode: "USD", decimalSeparator: ".", hasDecimals: true)
    ]

    static let defaultRegion: StorefrontRegion = supportedRegions[0]
}

// MARK: - App Search Result (iTunes Search / Lookup API)
struct AppSearchResult: Identifiable, Hashable, Codable {
    let trackId: Int
    let trackName: String
    let bundleId: String
    let sellerName: String
    let artworkUrl100: String
    let primaryGenreName: String?
    let formattedPrice: String?
    let averageUserRating: Double?

    var id: Int { trackId }

    var highResIconURL: URL? {
        let highRes = artworkUrl100.replacingOccurrences(of: "100x100bb", with: "256x256bb")
        return URL(string: highRes)
    }
}

struct ITunesSearchResponse: Codable {
    let resultCount: Int
    let results: [AppSearchResult]
}

// MARK: - Individual IAP Item parsed from App Store
struct IAPOfferItem: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String               // Tên gói IAP, ví dụ: "Super Duolingo"
    let rawPrice: String            // Giá gốc hiển thị trên Store, ví dụ: "599.000đ" hoặc "₺329,99"
    let numericPrice: Double?       // Giá trị số đã bóc tách
    let priceInVND: Double?         // Giá quy đổi ra VNĐ
    let region: StorefrontRegion    // Vùng Store tương ứng
    let rankIndex: Int              // Thứ tự xuất hiện trong danh sách IAP của Store

    init(
        id: UUID = UUID(),
        title: String,
        rawPrice: String,
        numericPrice: Double?,
        priceInVND: Double?,
        region: StorefrontRegion,
        rankIndex: Int
    ) {
        self.id = id
        self.title = title
        self.rawPrice = rawPrice
        self.numericPrice = numericPrice
        self.priceInVND = priceInVND
        self.region = region
        self.rankIndex = rankIndex
    }

    var formattedVND: String {
        guard let vnd = priceInVND, vnd > 0 else { return "Chưa rõ" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        let numStr = formatter.string(from: NSNumber(value: round(vnd))) ?? "\(Int(vnd))"
        return "\(numStr)đ"
    }
}

// MARK: - Grouped IAP Offers by Name (Phát hiện các mức giá ẩn / A-B Testing của cùng 1 gói)
struct IAPOfferGroup: Identifiable, Hashable {
    let id: String                  // Tên gói chuẩn hóa
    let title: String               // Tên hiển thị
    let offers: [IAPOfferItem]      // Tất cả các mức giá tìm thấy cho gói này (sắp xếp từ rẻ nhất -> đắt nhất)

    var cheapestOffer: IAPOfferItem? {
        offers.min { ($0.priceInVND ?? .greatestFiniteMagnitude) < ($1.priceInVND ?? .greatestFiniteMagnitude) }
    }

    var mostExpensiveOffer: IAPOfferItem? {
        offers.max { ($0.priceInVND ?? 0) < ($1.priceInVND ?? 0) }
    }

    /// Gói này có nhiều mức giá ẩn (A/B testing hoặc Retention tier) khác nhau hay không
    var hasHiddenPriceTiers: Bool {
        let distinctPrices = Set(offers.map { $0.rawPrice })
        return distinctPrices.count > 1
    }

    /// Phần trăm tiết kiệm được nếu chọn gói ẩn rẻ nhất so với gói đắt nhất cùng tên
    var maxSavingsPercentage: Int? {
        guard let minVND = cheapestOffer?.priceInVND,
              let maxVND = mostExpensiveOffer?.priceInVND,
              maxVND > minVND, maxVND > 0 else {
            return nil
        }
        return Int(round(((maxVND - minVND) / maxVND) * 100))
    }

    /// Số tiền VNĐ tiết kiệm được
    var maxSavingsVNDString: String? {
        guard let minVND = cheapestOffer?.priceInVND,
              let maxVND = mostExpensiveOffer?.priceInVND,
              maxVND > minVND else {
            return nil
        }
        let diff = maxVND - minVND
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        if let str = formatter.string(from: NSNumber(value: round(diff))) {
            return "\(str)đ"
        }
        return nil
    }
}

// MARK: - Multi-Region Scan Result for a single Country
struct RegionIAPScanResult: Identifiable, Hashable {
    var id: String { region.id }
    let region: StorefrontRegion
    let offers: [IAPOfferItem]
    let errorMessage: String?

    var cheapestOffer: IAPOfferItem? {
        offers.min { ($0.priceInVND ?? .greatestFiniteMagnitude) < ($1.priceInVND ?? .greatestFiniteMagnitude) }
    }
}

// MARK: - Popular Preset Apps known for Hidden IAPs
struct PresetAppItem: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let iconSystemName: String
    let badgeText: String

    static let popularApps: [PresetAppItem] = [
        PresetAppItem(id: 570060128, name: "Duolingo", subtitle: "Nhiều mức giá Super/Family ẩn", iconSystemName: "character.book.closed.fill", badgeText: "Hot Deal"),
        PresetAppItem(id: 1500855883, name: "CapCut", subtitle: "Gói Pro tháng/năm chênh lệch lớn", iconSystemName: "video.fill", badgeText: "Phổ biến"),
        PresetAppItem(id: 544007664, name: "YouTube", subtitle: "YouTube Premium đa vùng", iconSystemName: "play.rectangle.fill", badgeText: "Đa vùng"),
        PresetAppItem(id: 547702041, name: "Tinder", subtitle: "Nhiều tier Gold/Platinum A/B test", iconSystemName: "flame.fill", badgeText: "Nhiều gói ẩn"),
        PresetAppItem(id: 897446215, name: "Canva", subtitle: "Canva Pro & gói ưu đãi ẩn", iconSystemName: "paintbrush.pointed.fill", badgeText: "Thiết kế"),
        PresetAppItem(id: 6448311069, name: "ChatGPT", subtitle: "Kiểm tra gói Plus các vùng", iconSystemName: "sparkles", badgeText: "AI"),
        PresetAppItem(id: 1600525061, name: "Locket Widget", subtitle: "Locket Gold nhiều mức giá", iconSystemName: "heart.square.fill", badgeText: "Giới trẻ"),
        PresetAppItem(id: 959813437, name: "Bumble", subtitle: "Boost & Premium nhiều mức giá", iconSystemName: "bubble.left.and.bubble.right.fill", badgeText: "A/B Test")
    ]
}
