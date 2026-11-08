import SwiftUI
import UIKit

struct SearchView: View {
    @StateObject private var iapService = AppStoreIAPService.shared
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
                VStack(spacing: 18) {
                    // Search Box & Clipboard Quick Action
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Tên App, Link App Store hoặc App ID...", text: $searchText)
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
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                Task { await performSearch() }
                            } label: {
                                Text("Quét")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
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
                            Text("Đang truy vấn dữ liệu từ Apple App Store...")
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("KẾT QUẢ TÌM KIẾM (\(searchResults.count))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(searchResults) { app in
                                NavigationLink(value: app) {
                                    appRowView(app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Popular Apps with Hidden IAP Offers
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("APP PHỔ BIẾN NHIỀU GÓI IAP ẨN")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Chạm để quét ngay")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(PresetAppItem.popularApps) { preset in
                                    Button {
                                        Task { await openPresetApp(preset) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: preset.iconSystemName)
                                                    .font(.title3)
                                                    .foregroundStyle(.blue)
                                                    .frame(width: 36, height: 36)
                                                    .background(Color.blue.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                Spacer()
                                                Text(preset.badgeText)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.orange.opacity(0.15))
                                                    .foregroundStyle(.orange)
                                                    .clipShape(Capsule())
                                            }
                                            Text(preset.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(preset.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("IAP Hunter iOS")
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

    private func appRowView(_ app: AppSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.highResIconURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.trackName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(app.sellerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(app.bundleId)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func performSearch() async {
        isSearching = true
        errorMessage = nil
        do {
            searchResults = try await iapService.searchApps(query: searchText)
            if searchResults.isEmpty {
                errorMessage = "Không tìm thấy ứng dụng phù hợp. Hãy thử nhập tên khác hoặc dán link App Store."
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
            if let app = try await iapService.lookupApp(byId: preset.id) {
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
