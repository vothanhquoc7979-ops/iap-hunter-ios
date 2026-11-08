import Foundation
import StoreKit
import ObjectiveC

@MainActor
final class StoreKitDirectEngine: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    static let shared = StoreKitDirectEngine()

    @Published var discoveredProducts: [SKProduct] = []
    @Published var isScanning: Bool = false
    @Published var statusMessage: String = ""

    private var activeRequest: SKProductsRequest?

    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    /// Gọi trực tiếp bảng thanh toán App Store (FaceID) của hệ thống iOS cho bất kỳ mã SKU (productIdentifier) nào
    func triggerNativeAppStorePayment(skuId: String, fallbackProduct: SKProduct? = nil) {
        statusMessage = "⚡ Đang gọi bảng App Store (FaceID) cho SKU: \(skuId)..."

        // 1. Nếu đã có SKProduct từ SKProductsRequest thì gọi chuẩn
        if let product = fallbackProduct ?? discoveredProducts.first(where: { $0.productIdentifier == skuId }) {
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
            statusMessage = "✅ Đã bật bảng App Store cho gói \(product.localizedTitle)!"
            return
        }

        // 2. Nếu là SKU ẩn chưa qua SKProductsRequest, dùng Objective-C Runtime gọi thẳng +[SKPayment paymentWithProductIdentifier:]
        let selector = NSSelectorFromString("paymentWithProductIdentifier:")
        if SKPayment.responds(to: selector),
           let unmanaged = SKPayment.perform(selector, with: skuId),
           let rawPayment = unmanaged.takeUnretainedValue() as? SKPayment {
            SKPaymentQueue.default().add(rawPayment)
            statusMessage = "✅ Đã ép bật bảng thanh toán App Store trực tiếp cho mã SKU ẩn: \(skuId)!"
            return
        }

        // 3. Dự phòng: Truy vấn nhanh SKProductsRequest cho mã SKU này rồi tự bật bảng thanh toán khi có phản hồi
        let req = SKProductsRequest(productIdentifiers: Set([skuId]))
        req.delegate = self
        self.activeRequest = req
        req.start()
    }

    /// Quét sâu hàng loạt SKU ẩn từ StoreKit
    func scanDeepSKUs(for appId: Int, bundleId: String) {
        isScanning = true
        let candidates = buildCandidateSKUs(bundleId: bundleId)
        statusMessage = "🔍 Đang đào sâu \(candidates.count) mã SKU ẩn trên máy chủ StoreKit..."

        let req = SKProductsRequest(productIdentifiers: candidates)
        req.delegate = self
        self.activeRequest = req
        req.start()
    }

    private func buildCandidateSKUs(bundleId: String) -> Set<String> {
        var skus = Set<String>()
        let prefixes = [
            bundleId,
            "com.google.gemini",
            "com.google.one",
            "com.google.one.ai",
            "com.lemon.lvoverseas",
            "com.anthropic.claude",
            "com.openai.chat",
            "com.duolingo.super"
        ]
        let suffixes = [
            "ai.ultra.30tb.intro3m", "ai.ultra.30tb.monthly", "ai.ultra.20tb.intro3m", "ai.ultra.20tb.monthly",
            "ai.pro.5tb.intro3m", "ai.pro.5tb.monthly", "ai.pro.5tb.yearly", "ai.plus.400gb.intro3m", "ai.plus.2tb.monthly",
            "pro.monthly.intro", "standard.yearly.intro", "pro.yearly.v1", "pro.yearly.promo", "pro.yearly.tier2", "pro.yearly", "pro.1year",
            "pro.monthly", "max.5x.monthly.intro", "max.20x.monthly.intro", "plus.monthly.intro"
        ]
        for p in prefixes {
            for s in suffixes {
                skus.insert("\(p).\(s)")
            }
        }
        return skus
    }

    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            self.isScanning = false
            self.discoveredProducts = response.products.sorted { a, b in
                let aIntro = a.introductoryPrice != nil
                let bIntro = b.introductoryPrice != nil
                if aIntro != bIntro { return aIntro }
                return a.price.compare(b.price) == .orderedAscending
            }
            if let first = response.products.first, response.products.count == 1 {
                // Nếu chỉ truy vấn 1 SKU để mua ngay thì tự bật bảng App Store
                SKPaymentQueue.default().add(SKPayment(product: first))
                self.statusMessage = "✅ Đã bật bảng App Store cho \(first.localizedTitle)!"
            } else {
                self.statusMessage = "✅ Quét xong \(self.discoveredProducts.count) gói StoreKit thật!"
            }
        }
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // Giữ nguyên giao dịch cho hệ thống xử lý
    }
}
