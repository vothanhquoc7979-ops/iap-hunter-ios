import Foundation

@MainActor
final class SavedDealsManager: ObservableObject {
    static let shared = SavedDealsManager()

    @Published private(set) var savedApps: [AppSearchResult] = []
    private let storageKey = "IAPHunter.SavedApps.v1"

    private init() {
        load()
    }

    func isSaved(_ app: AppSearchResult) -> Bool {
        savedApps.contains { $0.trackId == app.trackId }
    }

    func toggleSave(_ app: AppSearchResult) {
        if let idx = savedApps.firstIndex(where: { $0.trackId == app.trackId }) {
            savedApps.remove(at: idx)
        } else {
            savedApps.insert(app, at: 0)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        savedApps.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppSearchResult].self, from: data) else {
            return
        }
        self.savedApps = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
