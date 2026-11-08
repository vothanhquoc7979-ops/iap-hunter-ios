import Foundation
import UIKit

@MainActor
final class CurrencyService: ObservableObject {
    static let shared = CurrencyService()

    @Published var activeRegion: StorefrontRegion = StorefrontRegion.defaultRegion

    /// Tỷ giá quy đổi 1 đơn vị ngoại tệ sang VNĐ (1 Currency = X VND)
    @Published private(set) var ratesToVND: [String: Double] = [
        "VND": 1.0,
        "USD": 25450.0,
        "TRY": 740.0,     // Lira Thổ Nhĩ Kỳ
        "NGN": 15.8,      // Naira Nigeria
        "EGP": 515.0,     // Bảng Ai Cập
        "INR": 301.0,     // Rupee Ấn Độ
        "PKR": 91.5,      // Rupee Pakistan
        "BRL": 4400.0,    // Real Brazil
        "IDR": 1.61,      // Rupiah Indonesia
        "PHP": 438.0      // Peso Philippines
    ]

    @Published private(set) var lastUpdated: Date?
    private var hasFetchedLiveRates = false

    private init() {
        if let savedId = UserDefaults.standard.string(forKey: "IAPHunter.ActiveRegion"),
           let found = StorefrontRegion.supportedRegions.first(where: { $0.id == savedId }) {
            self.activeRegion = found
        }
    }

    /// Chuyển vùng tự động + Sao chép sẵn thông tin Địa chỉ/Mã Zip của Quốc gia đó vào Clipboard iPhone
    func switchRegionAndCopyBilling(_ region: StorefrontRegion) {
        self.activeRegion = region
        UserDefaults.standard.set(region.id, forKey: "IAPHunter.ActiveRegion")
        UIPasteboard.general.string = region.billing.zipCode
    }

    /// Cập nhật tỷ giá trực tiếp từ Open Exchange Rates API (không cần API Key)
    func refreshRatesIfNeeded() async {
        guard !hasFetchedLiveRates else { return }
        await forceRefreshRates()
    }

    func forceRefreshRates() async {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return }

            struct ERResponse: Decodable {
                let rates: [String: Double]
            }

            let decoded = try JSONDecoder().decode(ERResponse.self, from: data)
            guard let usdToVND = decoded.rates["VND"], usdToVND > 0 else { return }

            var updatedRates: [String: Double] = ["VND": 1.0, "USD": usdToVND]
            for (code, ratePerUSD) in decoded.rates where ratePerUSD > 0 {
                updatedRates[code] = usdToVND / ratePerUSD
            }

            self.ratesToVND = updatedRates
            self.lastUpdated = Date()
            self.hasFetchedLiveRates = true
        } catch {
            // Giữ bảng tỷ giá dự phòng nếu lỗi mạng
        }
    }

    /// Bóc tách giá trị số từ chuỗi giá hiển thị trên App Store theo quy tắc của từng quốc gia
    nonisolated func parseNumericPrice(from rawPrice: String, region: StorefrontRegion) -> Double? {
        let trimmed = rawPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let lower = trimmed.lowercased()
        if lower == "free" || lower == "miễn phí" || lower == "ücretsiz" || lower == "gratis" {
            return 0.0
        }

        // Hỗ trợ hậu tố "ribu" (nghìn) và "juta" (triệu) của Indonesia trên App Store
        var multiplier: Double = 1.0
        if lower.contains("juta") || lower.contains("jt") {
            multiplier = 1_000_000.0
        } else if lower.contains("ribu") || lower.contains("rb") {
            multiplier = 1_000.0
        }

        if !region.hasDecimals && multiplier == 1.0 {
            let digitsOnly = trimmed.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            let numStr = String(String.UnicodeScalarView(digitsOnly))
            return Double(numStr)
        }

        let allowed = CharacterSet(charactersIn: "0123456789.,")
        let filteredScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
        var cleaned = String(String.UnicodeScalarView(filteredScalars))

        guard !cleaned.isEmpty else { return nil }

        if region.decimalSeparator == "," {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        guard let val = Double(cleaned) else { return nil }
        return val * multiplier
    }

    /// Quy đổi giá trị số của một vùng sang VNĐ
    func convertToVND(numericPrice: Double?, region: StorefrontRegion) -> Double? {
        guard let price = numericPrice else { return nil }
        if region.currencyCode == "VND" { return price }
        guard let rate = ratesToVND[region.currencyCode] else { return nil }
        return price * rate
    }
}
