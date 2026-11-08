import SwiftUI
import StoreKit
import UIKit

struct PurchaseActionSheet: View {
    let app: AppSearchResult
    let offer: IAPOfferItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copiedToast = false
    @State private var storeKitError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            AsyncImage(url: app.highResIconURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.secondary.opacity(0.2))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.trackName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("Bundle ID: \(app.bundleId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text("\(offer.region.flag) Store \(offer.region.name)")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("GÓI ĐÃ CHỌN")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(offer.title)
                                    .font(.title3.weight(.bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(offer.rawPrice)
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(.green)
                                if offer.region.currencyCode != "VND" {
                                    Text("≈ \(offer.formattedVND)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Action Buttons (Add để thanh toán)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KÍCH HOẠT & THANH TOÁN GÓI NÀY")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        // Nút 1: Mở trực tiếp Apple Subscriptions để chọn gói ẩn & thanh toán
                        Button {
                            openAppleSubscriptionsDeepLink()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.and.123")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mở Trang Đổi Gói & Thanh Toán (See All Plans)")
                                        .font(.subheadline.weight(.bold))
                                    Text("Mở thẳng danh sách toàn bộ gói ẩn trên Apple ID")
                                        .font(.caption2)
                                        .opacity(0.9)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward.app.fill")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Nút 2: Mở Sheet StoreKit 2 Native ngay trong App
                        Button {
                            Task {
                                await openNativeStoreKitSubscriptionSheet()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bật Sheet Quản Lý Gói Ngay Trong App (StoreKit 2)")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Hiển thị popup quản lý thuê bao của hệ thống iOS")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Nút 3: Mở trang App Store theo đúng Quốc gia của gói
                        Button {
                            openAppStoreForRegion()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bag.fill.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mở \(app.trackName) trên App Store (\(offer.region.flag) \(offer.region.name))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Tải app hoặc kích hoạt gói dùng thử (Free Trial)")
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

                        // Nút 4: Sao chép thông tin gói
                        Button {
                            UIPasteboard.general.string = "\(app.trackName) - \(offer.title): \(offer.rawPrice) (\(offer.formattedVND)) [Store \(offer.region.name)]"
                            copiedToast = true
                        } label: {
                            HStack {
                                Image(systemName: copiedToast ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(copiedToast ? "Đã sao chép thông tin gói!" : "Sao chép thông tin gói & giá")
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let storeKitError {
                        Text(storeKitError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Hướng dẫn 3 bước áp dụng gói ẩn không mất quyền lợi
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quy trình 3 bước Add gói ẩn để thanh toán", systemImage: "shield.checkered")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.blue)

                        stepRow(
                            num: "1",
                            title: "Kích hoạt dùng thử (Trial) trong \(app.trackName)",
                            desc: "Mở ứng dụng \(app.trackName), đăng ký gói Dùng thử miễn phí (Free Trial) hoặc gói bất kỳ để Apple liên kết tài khoản trong app với Apple ID."
                        )

                        stepRow(
                            num: "2",
                            title: "Mở danh sách 'See All Plans' của Apple",
                            desc: "Bấm nút màu xanh phía trên để mở trang Quản lý Đăng ký của iOS -> Chọn \(app.trackName) -> Bấm 'Xem tất cả các gói (See All Plans)'."
                        )

                        stepRow(
                            num: "3",
                            title: "Chọn gói ẩn \(offer.rawPrice) & Xác nhận FaceID",
                            desc: "Chọn đúng gói '\(offer.title)' với mức giá \(offer.rawPrice) (\(offer.formattedVND)). Apple sẽ tự động chuyển đổi sang gói giá rẻ này ngay lập tức!"
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Thanh Toán Gói Ẩn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                // Tự động chạy ngầm: đồng bộ vùng của Offer & mở cổng thanh toán của đúng App chứa gói ẩn
                CurrencyService.shared.switchRegionAndCopyBilling(offer.region)
                try? await Task.sleep(nanoseconds: 600_000_000)
                openAppleSubscriptionsDeepLink()
            }
        }
    }

    private func stepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    @MainActor
    private func openNativeStoreKitSubscriptionSheet() async {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            openAppleSubscriptionsDeepLink()
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: windowScene)
        } catch {
            storeKitError = "Không thể mở popup trong Simulator/môi trường hiện tại, đang chuyển sang trang Cài đặt của iOS..."
            openAppleSubscriptionsDeepLink()
        }
    }
}
