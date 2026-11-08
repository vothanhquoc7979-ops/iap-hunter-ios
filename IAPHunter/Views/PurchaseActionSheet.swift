import SwiftUI
import StoreKit
import UIKit

struct PurchaseActionSheet: View {
    let app: AppSearchResult
    let offer: IAPOfferItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var storeEngine = StoreKitDirectEngine.shared
    @State private var copiedToast = false
    @State private var customSkuInput: String = ""

    private var inferredSku: String {
        if !customSkuInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customSkuInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let slug = offer.title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: ".", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return "\(app.bundleId).\(slug)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header "Xác nhận mua" chuẩn y hệt ảnh chụp
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            AsyncImage(url: app.highResIconURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.secondary.opacity(0.2))
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(offer.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("\(targetAppDisplayName) • \(offer.region.flag) \(offer.region.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    Text("GIẢM KỲ ĐẦU")
                                        .font(.system(size: 10, weight: .heavy))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.24))
                                        .foregroundStyle(Color(red: 1.0, green: 0.41, blue: 0.38))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))

                                    Text("ẨN")
                                        .font(.system(size: 10, weight: .heavy))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.gray.opacity(0.28))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                            Spacer()
                        }

                        Divider().overlay(Color.white.opacity(0.12))

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("GIÁ ƯU ĐÃI / GÓI ẨN")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text("\(offer.rawPrice)/kỳ")
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(.green)
                                if offer.region.currencyCode != "VND" {
                                    Text("Quy đổi ≈ \(offer.formattedVND)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mã SKU StoreKit (productIdentifier):")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("Nhập hoặc sửa mã SKU...", text: $customSkuInput)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.black.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(Color(red: 0.09, green: 0.09, blue: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    if !storeEngine.statusMessage.isEmpty {
                        Text(storeEngine.statusMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Nút 1: GỌI TRỰC TIẾP SKPaymentQueue BẬT BẢNG APP STORE (FACEID) ĐÈ LÊN MÀN HÌNH
                    Button {
                        storeEngine.triggerNativeAppStorePayment(skuId: inferredSku)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "applelogo")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bật Bảng App Store (FaceID) Mua Ngay")
                                    .font(.subheadline.weight(.bold))
                                Text("Ép SKPaymentQueue bật popup Đăng ký (\(offer.rawPrice)) ngay trên màn hình")
                                    .font(.caption2)
                                    .opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "bolt.fill")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Nút 2: Mở trực tiếp Apple Subscriptions (See All Plans)
                    Button {
                        openAppleSubscriptionsDeepLink()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard.and.123")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mở 'Xem tất cả các gói (See All Plans)'")
                                    .font(.subheadline.weight(.bold))
                                Text("Mở danh sách gói ẩn trong Cài đặt Apple ID")
                                    .font(.caption2)
                                    .opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Nút 3: Mở App Store theo vùng
                    Button {
                        openAppStoreForRegion()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bag.fill.badge.plus")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mở \(targetAppDisplayName) trên App Store (\(offer.region.flag))")
                                    .font(.subheadline.weight(.semibold))
                                Text("Tải App đích hoặc kích hoạt gói dùng thử")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Xác nhận mua")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                customSkuInput = inferredSku
                CurrencyService.shared.switchRegionAndCopyBilling(offer.region)
                // Tự động kích hoạt bảng thanh toán App Store (SKPaymentQueue) ngay khi mở "Xác nhận mua"
                try? await Task.sleep(nanoseconds: 400_000_000)
                storeEngine.triggerNativeAppStorePayment(skuId: inferredSku)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var targetAppId: Int {
        offer.sourceAppId ?? app.trackId
    }

    private var targetAppDisplayName: String {
        offer.sourceAppName ?? app.trackName
    }

    private func openAppleSubscriptionsDeepLink() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions?app-id=\(targetAppId)") {
            openURL(url)
        } else if let webUrl = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(webUrl)
        }
    }

    private func openAppStoreForRegion() {
        if let url = URL(string: "itms-apps://itunes.apple.com/\(offer.region.id)/app/id\(targetAppId)?mt=8") {
            openURL(url)
        } else if let webUrl = URL(string: "https://apps.apple.com/\(offer.region.id)/app/id\(targetAppId)") {
            openURL(webUrl)
        }
    }
}
