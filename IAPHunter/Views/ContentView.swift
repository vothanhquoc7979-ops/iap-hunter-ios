import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("Quét Gói Ẩn", systemImage: "sparkle.magnifyingglass")
                }

            RegionSwitcherView()
                .tabItem {
                    Label("Đổi Vùng ID", systemImage: "globe.asia.australia.fill")
                }

            SavedAppsView()
                .tabItem {
                    Label("Đã Lưu & Tỷ Giá", systemImage: "bookmark.fill")
                }
        }
        .task {
            await CurrencyService.shared.refreshRatesIfNeeded()
        }
    }
}
