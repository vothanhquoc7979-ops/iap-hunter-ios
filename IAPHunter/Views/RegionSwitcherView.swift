import SwiftUI
import UIKit

struct RegionSwitcherView: View {
    @StateObject private var currencyService = CurrencyService.shared
    @Environment(\.openURL) private var openURL
    @State private var selectedRegionForSheet: StorefrontRegion?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự Động Hóa Đổi Vùng Apple ID / App Store", systemImage: "globe.badge.chevron.backward")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.blue)
                        Text("Khi bạn chạm vào nút 'Đổi Vùng' ở bất kỳ quốc gia nào bên dưới, ứng dụng sẽ tự động:\n1. Chuyển vùng quét giá mặc định sang nước đó.\n2. Tự động Copy sẵn Mã Bưu Chính (Zip Code) & Địa chỉ chuẩn miễn thuế vào bộ nhớ tạm iPhone.\n3. Mở thẳng màn hình Quốc gia/Vùng của Apple ID để bạn dán (Paste) trong 3 giây.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if let toastMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(toastMessage)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }

                Section("Danh sách 10 Quốc gia Giá Rẻ") {
                    ForEach(StorefrontRegion.supportedRegions) { region in
                        let isCurrent = (currencyService.activeRegion.id == region.id)
                        HStack(spacing: 12) {
                            Text(region.flag)
                                .font(.title)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("\(region.name) (\(region.currencyCode))")
                                        .font(.subheadline.weight(.semibold))
                                    if isCurrent {
                                        Text("ĐANG DÙNG")
                                            .font(.system(size: 9, weight: .heavy))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundStyle(.green)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(region.billing.city) • Zip: \(region.billing.zipCode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                currencyService.switchRegionAndCopyBilling(region)
                                toastMessage = "Đã chuyển sang \(region.flag) \(region.name) & Copy Zip: \(region.billing.zipCode)"
                                selectedRegionForSheet = region
                            } label: {
                                Text(isCurrent ? "Chi Tiết" : "Đổi Vùng")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isCurrent ? Color.green.opacity(0.18) : Color.blue.opacity(0.15))
                                    .foregroundStyle(isCurrent ? .green : .blue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle("Đổi Vùng ID")
            .sheet(item: $selectedRegionForSheet) { region in
                NavigationStack {
                    List {
                        Section("Thông tin địa chỉ chuẩn (\(region.flag) \(region.name))") {
                            copyRow(label: "Đường (Street)", value: region.billing.street)
                            copyRow(label: "Thành phố (City)", value: region.billing.city)
                            copyRow(label: "Bang / Tỉnh (State)", value: region.billing.state)
                            copyRow(label: "Mã Zip / Postcode (Đã tự động Copy)", value: region.billing.zipCode)
                            copyRow(label: "Số điện thoại (Phone)", value: region.billing.phone)
                        }

                        Section {
                            Button {
                                if let url = URL(string: "itms-apps://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/accountSummary") {
                                    openURL(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app.fill")
                                    Text("Mở Thẳng Cài Đặt Quốc Gia Apple ID")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .navigationTitle("\(region.flag) \(region.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Đóng") { selectedRegionForSheet = nil }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func copyRow(label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                toastMessage = "Đã copy \(label): \(value)"
            } label: {
                Text("Copy")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
