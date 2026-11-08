import SwiftUI

struct SavedAppsView: View {
    @StateObject private var savedManager = SavedDealsManager.shared
    @StateObject private var currencyService = CurrencyService.shared
    @State private var isRefreshingRates = false

    var body: some View {
        NavigationStack {
            List {
                Section("Ứng dụng đã lưu (\(savedManager.savedApps.count))") {
                    if savedManager.savedApps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bookmark.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Chưa có ứng dụng nào được lưu.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(savedManager.savedApps) { app in
                            NavigationLink(value: app) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: app.highResIconURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.secondary.opacity(0.2))
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.trackName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(app.bundleId)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: savedManager.remove)
                    }
                }

                Section {
                    ForEach(StorefrontRegion.supportedRegions.filter { $0.currencyCode != "VND" }) { region in
                        HStack {
                            Text("\(region.flag) \(region.name) (1 \(region.currencyCode))")
                                .font(.subheadline)
                            Spacer()
                            if let rate = currencyService.ratesToVND[region.currencyCode] {
                                Text(formatRate(rate))
                                    .font(.subheadline.monospaced().weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Tỷ giá quy đổi sang VNĐ")
                        Spacer()
                        Button {
                            Task {
                                isRefreshingRates = true
                                await currencyService.forceRefreshRates()
                                isRefreshingRates = false
                            }
                        } label: {
                            if isRefreshingRates {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Cập nhật")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Đã Lưu & Tỷ Giá")
            .navigationDestination(for: AppSearchResult.self) { app in
                AppIAPDetailView(app: app)
            }
        }
    }

    private func formatRate(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = rate < 50 ? 2 : 0
        let str = formatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
        return "\(str)đ"
    }
}
