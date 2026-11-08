import Foundation

// MARK: - Billing Info for Apple ID Region Switching
struct RegionBillingTemplate: Hashable, Codable {
    let street: String
    let city: String
    let state: String
    let zipCode: String
    let phone: String
}

// MARK: - Storefront / Country Region Model
struct StorefrontRegion: Identifiable, Hashable, Codable {
    let id: String          // ISO country code lowercase, e.g. "vn", "tr", "ng"
    let name: String        // Tên quốc gia tiếng Việt
    let flag: String        // Emoji cờ
    let currencyCode: String // Mã tiền tệ ISO, e.g. "VND", "TRY", "NGN"
    let decimalSeparator: String // Dấu phân cách thập phân chuẩn trên App Store của vùng đó
    let hasDecimals: Bool   // Tiền tệ có phần thập phân trên App Store hay không
    let billing: RegionBillingTemplate

    static let supportedRegions: [StorefrontRegion] = [
        StorefrontRegion(
            id: "vn", name: "Việt Nam", flag: "🇻🇳", currencyCode: "VND", decimalSeparator: ",", hasDecimals: false,
            billing: RegionBillingTemplate(street: "123 Lê Lợi, Quận 1", city: "Hồ Chí Minh", state: "Hồ Chí Minh", zipCode: "700000", phone: "0901234567")
        ),
        StorefrontRegion(
            id: "tr", name: "Thổ Nhĩ Kỳ", flag: "🇹🇷", currencyCode: "TRY", decimalSeparator: ",", hasDecimals: true,
            billing: RegionBillingTemplate(street: "Istiklal Cad. No 45 Beyoglu", city: "Istanbul", state: "Istanbul", zipCode: "34430", phone: "5321234567")
        ),
        StorefrontRegion(
            id: "ng", name: "Nigeria", flag: "🇳🇬", currencyCode: "NGN", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "14 Ahmadu Bello Way, Victoria Island", city: "Lagos", state: "Lagos", zipCode: "101241", phone: "8031234567")
        ),
        StorefrontRegion(
            id: "eg", name: "Ai Cập", flag: "🇪🇬", currencyCode: "EGP", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "22 Tahrir Square, Downtown", city: "Cairo", state: "Cairo", zipCode: "11511", phone: "1001234567")
        ),
        StorefrontRegion(
            id: "in", name: "Ấn Độ", flag: "🇮🇳", currencyCode: "INR", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "42 MG Road, Connaught Place", city: "New Delhi", state: "Delhi", zipCode: "110001", phone: "9810123456")
        ),
        StorefrontRegion(
            id: "pk", name: "Pakistan", flag: "🇵🇰", currencyCode: "PKR", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "18 Main Boulevard Gulberg", city: "Lahore", state: "Punjab", zipCode: "54660", phone: "3001234567")
        ),
        StorefrontRegion(
            id: "br", name: "Brazil", flag: "🇧🇷", currencyCode: "BRL", decimalSeparator: ",", hasDecimals: true,
            billing: RegionBillingTemplate(street: "Av. Paulista 1578, Bela Vista", city: "Sao Paulo", state: "SP", zipCode: "01310-200", phone: "11987654321")
        ),
        StorefrontRegion(
            id: "id", name: "Indonesia", flag: "🇮🇩", currencyCode: "IDR", decimalSeparator: ",", hasDecimals: false,
            billing: RegionBillingTemplate(street: "Jl. MH Thamrin No. 10", city: "Jakarta Pusat", state: "DKI Jakarta", zipCode: "10310", phone: "81234567890")
        ),
        StorefrontRegion(
            id: "ph", name: "Philippines", flag: "🇵🇭", currencyCode: "PHP", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "6750 Ayala Avenue", city: "Makati", state: "Metro Manila", zipCode: "1226", phone: "9171234567")
        ),
        StorefrontRegion(
            id: "us", name: "Mỹ (US - 0% Thuế)", flag: "🇺🇸", currencyCode: "USD", decimalSeparator: ".", hasDecimals: true,
            billing: RegionBillingTemplate(street: "700 SW 5th Ave", city: "Portland", state: "OR (Oregon)", zipCode: "97204", phone: "5035550199")
        )
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
    let title: String               // Tên gói IAP
    let rawPrice: String            // Giá gốc hiển thị trên Store
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

// MARK: - Grouped IAP Offers by Name
struct IAPOfferGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let offers: [IAPOfferItem]

    var cheapestOffer: IAPOfferItem? {
        offers.min { ($0.priceInVND ?? .greatestFiniteMagnitude) < ($1.priceInVND ?? .greatestFiniteMagnitude) }
    }

    var mostExpensiveOffer: IAPOfferItem? {
        offers.max { ($0.priceInVND ?? 0) < ($1.priceInVND ?? 0) }
    }

    var hasHiddenPriceTiers: Bool {
        let distinctPrices = Set(offers.map { $0.rawPrice })
        return distinctPrices.count > 1
    }

    var maxSavingsPercentage: Int? {
        guard let minVND = cheapestOffer?.priceInVND,
              let maxVND = mostExpensiveOffer?.priceInVND,
              maxVND > minVND, maxVND > 0 else {
            return nil
        }
        return Int(round(((maxVND - minVND) / maxVND) * 100))
    }

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

// MARK: - Popular Preset Apps with Real App Store Icons (Including Google One)
struct PresetAppItem: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let iconURLString: String
    let badgeText: String

    var iconURL: URL? { URL(string: iconURLString) }

    static let popularApps: [PresetAppItem] = [
        PresetAppItem(
            id: 1451784328,
            name: "Google One",
            subtitle: "100GB, 200GB, 2TB & Google AI Plus đa quốc gia",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/dc/2e/e5/dc2ee5ef-a9fe-5e46-c268-08152216c862/logo_one_color-0-0-1x_U007emarketing-0-0-0-7-0-0-0-0-85-220.png/256x256bb.jpg",
            badgeText: "Rẻ hơn 65%"
        ),
        PresetAppItem(
            id: 570060128,
            name: "Duolingo",
            subtitle: "Gói Super Duolingo ẩn 599.000đ (Giá gốc 860.000đ)",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/8c/31/28/8c312832-119b-31b5-86a0-07450171d52d/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/256x256bb.jpg",
            badgeText: "-261.000đ"
        ),
        PresetAppItem(
            id: 547702041,
            name: "Tinder",
            subtitle: "Tinder Gold ẩn 56.000đ (VN) & 20.500đ (Thổ Nhĩ Kỳ)",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/7a/39/53/7a39535c-d91c-82a7-019b-f2b741393987/AppIcon-0-0-1x_U007emarketing-0-7-0-0-85-220.png/256x256bb.jpg",
            badgeText: "Ẩn -70%"
        ),
        PresetAppItem(
            id: 1500855883,
            name: "CapCut",
            subtitle: "Gói Standard/Monthly ẩn 117.000đ vs 222.000đ",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/0f/10/c5/0f10c5b6-0564-9a43-501c-6a2186192350/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/256x256bb.jpg",
            badgeText: "Phổ biến"
        ),
        PresetAppItem(
            id: 544007664,
            name: "YouTube",
            subtitle: "So sánh gói YouTube Premium & Music 10 nước",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/54/2c/c2/542cc28f-06a7-52b9-3644-b61493f83226/logo_youtube_2024_q4_color-0-1x_U007emarketing-0-0-0-7-0-0-0-85-220-0.png/256x256bb.jpg",
            badgeText: "Đa vùng"
        ),
        PresetAppItem(
            id: 6448311069,
            name: "ChatGPT",
            subtitle: "Kiểm tra giá gói ChatGPT Plus các vùng Store",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/0b/2c/4c/0b2c4cd6-9371-3d26-59a8-2a7a1d512008/AppIcon-0-0-1x_U007epad-0-1-0-85-220.png/256x256bb.jpg",
            badgeText: "AI Plus"
        ),
        PresetAppItem(
            id: 897446215,
            name: "Canva",
            subtitle: "Các gói Canva Pro tháng & năm ẩn theo vùng",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/85/79/4b/85794b8d-0861-5832-3137-04a9b617a306/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/256x256bb.jpg",
            badgeText: "Thiết kế"
        ),
        PresetAppItem(
            id: 1600525061,
            name: "Locket Widget",
            subtitle: "Locket Gold nhiều mức giá ưu đãi ẩn",
            iconURLString: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/7d/49/46/7d494647-e052-885c-6947-761771306332/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/256x256bb.jpg",
            badgeText: "Giới trẻ"
        )
    ]
}
