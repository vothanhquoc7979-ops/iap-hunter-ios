import Foundation

@MainActor
final class CurrencyService: ObservableObject {
    static let shared = CurrencyService()

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

    private init() {}

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
                // 1 USD = ratePerUSD [code] => 1 [code] = usdToVND / ratePerUSD VND
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

        // Nếu tiền tệ không có số thập phân trên App Store (như VND, IDR, JPY)
        if !region.hasDecimals {
            let digitsOnly = trimmed.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            let numStr = String(String.UnicodeScalarView(digitsOnly))
            return Double(numStr)
        }

        // Lọc chỉ giữ chữ số, dấu chấm và dấu phẩy
        let allowed = CharacterSet(charactersIn: "0123456789.,")
        let filteredScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
        var cleaned = String(String.UnicodeScalarView(filteredScalars))

        guard !cleaned.isEmpty else { return nil }

        if region.decimalSeparator == "," {
            // Ví dụ Thổ Nhĩ Kỳ / Brazil: "1.209,99" -> bỏ dấu ".", đổi "," thành "."
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            // Ví dụ Mỹ / Nigeria / Ấn Độ / Ai Cập: "47,500.00" hoặc "1,379" -> bỏ dấu ","
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        return Double(cleaned)
    }

    /// Quy đổi giá trị số của một vùng sang VNĐ
    func convertToVND(numericPrice: Double?, region: StorefrontRegion) -> Double? {
        guard let price = numericPrice else { return nil }
        if region.currencyCode == "VND" { return price }
        guard let rate = ratesToVND[region.currencyCode] else { return nil }
        return price * rate
    }
}
