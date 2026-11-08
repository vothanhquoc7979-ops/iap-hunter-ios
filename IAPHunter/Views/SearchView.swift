import SwiftUI
import UIKit

struct SearchView: View {
    @StateObject private var iapService = AppStoreIAPService.shared
    @StateObject private var currencyService = CurrencyService.shared
    @State private var searchText = ""
    @State private var searchResults: [AppSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedAppForNavigation: AppSearchResult?
    @State private var isLoadingPreset = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Search Box & Clipboard Quick Action
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Tìm Google One, Duolingo, Link App...", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.search)
                                    .onSubmit {
                                        Task { await performSearch() }
                                    }
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(11)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                Task { await performSearch() }
                            } label: {
                                Text("Tìm")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                        }

                        HStack(spacing: 10) {
                            Button {
                                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                    searchText = clip
                                    Task { await performSearch() }
                                }
                            } label: {
                                Label("Dán Link / ID", systemImage: "doc.on.clipboard")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    openURL(url)
                                }
                            } label: {
                                Label("Mở See All Plans iOS", systemImage: "creditcard.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.14))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)

                    if isSearching || isLoadingPreset {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Đang kết nối Apple App Store...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                    }

                    // Search Results List
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("KẾT QUẢ TÌM KIẾM (\(searchResults.count))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, app in
                                    NavigationLink(value: app) {
                                        appCellView(app)
                                    }
                                    .buttonStyle(.plain)
                                    if index < searchResults.count - 1 {
                                        Divider().padding(.leading, 78)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }
                    } else {
                        // Authentic iOS App Store Inset Grouped List for Presets (Including Google One)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("GÓI IAP ẨN NỔI BẬT (GỒM GOOGLE ONE)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Chạm để quét")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(PresetAppItem.popularApps.enumerated()), id: \.element.id) { index, preset in
                                    Button {
                                        Task { await openPresetApp(preset) }
                                    } label: {
                                        HStack(spacing: 13) {
                                            AsyncImage(url: preset.iconURL) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.secondary.opacity(0.2))
                                            }
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(preset.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Text(preset.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                Text(preset.badgeText)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.16))
                                                    .foregroundStyle(.green)
                                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                            }

                                            Spacer()

                                            Text("QUÉT")
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(Color.blue.opacity(0.16))
                                                .foregroundStyle(.blue)
                                                .clipShape(Capsule())
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                    }
                                    .buttonStyle(.plain)

                                    if index < PresetAppItem.popularApps.count - 1 {
                                        Divider().padding(.leading, 80)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("IAP Hunter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(StorefrontRegion.supportedRegions) { region in
                            Button {
                                currencyService.switchRegionAndCopyBilling(region)
                            } label: {
                                Text("\(region.flag) \(region.name) (\(region.currencyCode))")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currencyService.activeRegion.flag)
                            Text(currencyService.activeRegion.id.uppercased())
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                }
            }
            .navigationDestination(for: AppSearchResult.self) { app in
                AppIAPDetailView(app: app)
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedAppForNavigation != nil },
                set: { if !$0 { selectedAppForNavigation = nil } }
            )) {
                if let app = selectedAppForNavigation {
                    AppIAPDetailView(app: app)
                }
            }
        }
    }

    private func appCellView(_ app: AppSearchResult) -> some View {
        HStack(spacing: 13) {
            AsyncImage(url: app.highResIconURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.trackName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(app.sellerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("QUÉT")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.16))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func performSearch() async {
        isSearching = true
        errorMessage = nil
        do {
            searchResults = try await iapService.searchApps(query: searchText, country: currencyService.activeRegion.id)
            if searchResults.isEmpty {
                errorMessage = "Không tìm thấy ứng dụng phù hợp."
            }
        } catch {
            errorMessage = "Lỗi kết nối: \(error.localizedDescription)"
        }
        isSearching = false
    }

    private func openPresetApp(_ preset: PresetAppItem) async {
        isLoadingPreset = true
        errorMessage = nil
        do {
            if let app = try await iapService.lookupApp(byId: preset.id, country: currencyService.activeRegion.id) {
                selectedAppForNavigation = app
            } else {
                errorMessage = "Không thể tải thông tin ứng dụng \(preset.name)."
            }
        } catch {
            errorMessage = "Lỗi tải ứng dụng: \(error.localizedDescription)"
        }
        isLoadingPreset = false
    }
}
