import SwiftUI

struct AppIAPDetailView: View {
    let app: AppSearchResult

    @StateObject private var iapService = AppStoreIAPService.shared
    @StateObject private var currencyService = CurrencyService.shared
    @StateObject private var savedManager = SavedDealsManager.shared

    @State private var selectedTab: DetailTab = .singleRegion
    @State private var selectedRegion: StorefrontRegion = .defaultRegion

    // Single region state
    @State private var regionOffers: [IAPOfferItem] = []
    @State private var isLoadingSingle = false
    @State private var singleError: String?
    @State private var groupSameNameOffers = true
    @State private var showOnlyHiddenOffers = false

    // Multi-region comparison state
    @State private var multiRegionResults: [RegionIAPScanResult] = []
    @State private var isScanningMulti = false
    @State private var filterKeyword = ""

    // Selected offer for payment sheet
    @State private var selectedOfferForPurchase: IAPOfferItem?

    enum DetailTab: String, CaseIterable {
        case singleRegion = "Phân Tích Gói Ẩn"
        case multiRegion = "So Sánh 10 Quốc Gia"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                appHeaderCard

                Picker("Chế độ xem", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedTab == .singleRegion {
                    singleRegionSection
                } else {
                    multiRegionComparisonSection
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(app.trackName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    savedManager.toggleSave(app)
                } label: {
                    Image(systemName: savedManager.isSaved(app) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(savedManager.isSaved(app) ? .orange : .primary)
                }
            }
        }
        .sheet(item: $selectedOfferForPurchase) { offer in
            PurchaseActionSheet(app: app, offer: offer)
        }
        .task {
            await loadSingleRegionOffers()
        }
        .onChange(of: selectedRegion) { _ in
            Task { await loadSingleRegionOffers() }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .multiRegion && multiRegionResults.isEmpty && !isScanningMulti {
                Task { await runMultiRegionScan() }
            }
        }
    }

    // MARK: - App Header Card
    private var appHeaderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                AsyncImage(url: app.highResIconURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.trackName)
                        .font(.headline)
                        .lineLimit(2)
                    Text(app.sellerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("ID: \(String(app.trackId))")
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))

                        if let genre = app.primaryGenreName {
                            Text(genre)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Tab 1: Single Region Hidden IAP Analyzer
    private var singleRegionSection: some View {
        VStack(spacing: 14) {
            // Country Selector Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StorefrontRegion.supportedRegions) { region in
                        Button {
                            selectedRegion = region
                        } label: {
                            HStack(spacing: 6) {
                                Text(region.flag)
                                Text(region.name)
                                    .font(.subheadline.weight(selectedRegion == region ? .bold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedRegion == region ? Color.blue : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedRegion == region ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }

            if isLoadingSingle {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Đang quét danh sách gói IAP trên Store \(selectedRegion.flag) \(selectedRegion.name)...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let singleError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(singleError)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Thử lại") {
                        Task { await loadSingleRegionOffers() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(30)
            } else if regionOffers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Ứng dụng này không công bố gói IAP tại vùng \(selectedRegion.name) hoặc không có mặt tại Store này.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
            } else {
                // Summary Banner
                let groups = iapService.groupOffersByTitle(regionOffers)
                let hiddenTierGroups = groups.filter { $0.hasHiddenPriceTiers }
                let hiddenTierGroupsCount = hiddenTierGroups.count

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tìm thấy \(regionOffers.count) gói IAP (\(groups.count) nhóm gói)")
                                .font(.subheadline.weight(.bold))
                            if hiddenTierGroupsCount > 0 {
                                Text("Phát hiện \(hiddenTierGroupsCount) gói có Offer Ẩn (A/B Testing) rẻ hơn giá gốc!")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Hiển thị đầy đủ giá gốc và quy đổi VNĐ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("Gom nhóm", isOn: $groupSameNameOffers)
                            .labelsHidden()
                    }

                    if hiddenTierGroupsCount > 0 {
                        Divider()
                        Toggle(isOn: $showOnlyHiddenOffers) {
                            Label("Chỉ hiển thị các gói có Offer Ẩn giá rẻ", systemImage: "eye.trianglebadge.exclamationmark.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                let displayedGroups = showOnlyHiddenOffers ? hiddenTierGroups : groups

                if groupSameNameOffers {
                    ForEach(displayedGroups) { group in
                        offerGroupCard(group)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(regionOffers) { offer in
                            singleOfferRow(offer: offer, isCheapestInGroup: false)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Grouped Offer Card (Highlights Hidden Cheaper Tiers)
    private func offerGroupCard(_ group: IAPOfferGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                    if group.hasHiddenPriceTiers {
                        HStack(spacing: 6) {
                            Label("Có \(group.offers.count) biến thể giá ẩn", systemImage: "eye.trianglebadge.exclamationmark.fill")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())

                            if let pct = group.maxSavingsPercentage, let savedStr = group.maxSavingsVNDString {
                                Text("Rẻ hơn \(pct)% (-\(savedStr))")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                let cheapestVND = group.cheapestOffer?.priceInVND
                ForEach(group.offers) { offer in
                    let isCheapest = group.hasHiddenPriceTiers && (offer.priceInVND != nil) && (offer.priceInVND == cheapestVND)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Gói #\(offer.rankIndex)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                if isCheapest {
                                    Text("DEAL ẨN RẺ NHẤT")
                                        .font(.system(size: 10, weight: .heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(offer.rawPrice)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isCheapest ? .green : .primary)
                            if offer.region.currencyCode != "VND" {
                                Text("≈ \(offer.formattedVND)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            selectedOfferForPurchase = offer
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "cart.badge.plus")
                                Text("Add Thanh Toán")
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isCheapest ? Color.green : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isCheapest ? Color.green.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func singleOfferRow(offer: IAPOfferItem, isCheapestInGroup: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(offer.title)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(offer.rawPrice)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                    if offer.region.currencyCode != "VND" {
                        Text("(≈ \(offer.formattedVND))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                selectedOfferForPurchase = offer
            } label: {
                Label("Add", systemImage: "cart.badge.plus")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Tab 2: Multi-Region Price Comparison (10 Countries -> VND)
    private var multiRegionComparisonSection: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("Lọc theo tên gói (vd: Super, Pro, Monthly)...", text: $filterKeyword)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await runMultiRegionScan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .disabled(isScanningMulti)
            }
            .padding(.horizontal)

            if isScanningMulti {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Đang quét đồng thời 10 Quốc gia (VN, Thổ Nhĩ Kỳ, Nigeria, Ai Cập, Ấn Độ...) và quy đổi ra VNĐ...")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 40)
            } else {
                // Best Global Offer Banner
                if let globalCheapest = findGlobalCheapestOffer() {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("VÙNG RẺ NHẤT TOÀN CẦU", systemImage: "crown.fill")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.yellow)
                            Spacer()
                            Text("\(globalCheapest.region.flag) Store \(globalCheapest.region.name)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(globalCheapest.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Giá gốc: \(globalCheapest.rawPrice)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(globalCheapest.formattedVND)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.green)
                                Button {
                                    selectedOfferForPurchase = globalCheapest
                                } label: {
                                    Text("Mua Ngay")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .foregroundStyle(.black)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Region Cards
                ForEach(multiRegionResults) { result in
                    let filteredOffers = filtered(offers: result.offers)
                    if !filteredOffers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(result.region.flag) \(result.region.name) (\(result.region.currencyCode))")
                                    .font(.headline)
                                Spacer()
                                if let minOffer = filteredOffers.min(by: { ($0.priceInVND ?? .infinity) < ($1.priceInVND ?? .infinity) }) {
                                    Text("Từ \(minOffer.formattedVND)")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                            }

                            Divider()

                            ForEach(filteredOffers.prefix(8)) { offer in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(offer.title)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Text(offer.rawPrice)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(offer.formattedVND)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .padding(.trailing, 6)

                                    Button {
                                        selectedOfferForPurchase = offer
                                    } label: {
                                        Image(systemName: "cart.badge.plus")
                                            .font(.caption.weight(.bold))
                                            .padding(8)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func filtered(offers: [IAPOfferItem]) -> [IAPOfferItem] {
        let kw = filterKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return offers }
        return offers.filter { $0.title.lowercased().contains(kw) }
    }

    private func findGlobalCheapestOffer() -> IAPOfferItem? {
        let allOffers = multiRegionResults.flatMap { filtered(offers: $0.offers) }
        return allOffers
            .filter { ($0.priceInVND ?? 0) > 0 }
            .min { ($0.priceInVND ?? .greatestFiniteMagnitude) < ($1.priceInVND ?? .greatestFiniteMagnitude) }
    }

    private func loadSingleRegionOffers() async {
        isLoadingSingle = true
        singleError = nil
        do {
            regionOffers = try await iapService.fetchIAPOffers(appId: app.trackId, region: selectedRegion)
        } catch {
            singleError = "Không thể tải dữ liệu: \(error.localizedDescription)"
        }
        isLoadingSingle = false
    }

    private func runMultiRegionScan() async {
        isScanningMulti = true
        multiRegionResults = await iapService.scanMultiRegionIAPs(appId: app.trackId)
        isScanningMulti = false
    }
}
