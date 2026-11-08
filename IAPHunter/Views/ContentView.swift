import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("Quét IAP Ẩn", systemImage: "sparkle.magnifyingglass")
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
