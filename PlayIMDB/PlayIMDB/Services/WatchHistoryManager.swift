import Foundation

@MainActor
final class WatchHistoryManager: ObservableObject {
    static let shared = WatchHistoryManager()

    @Published var history: [WatchHistoryItem] = []

    private let saveKey = "PlayIMDB_WatchHistory"
    private let maxItems = 50

    private init() {
        loadHistory()
    }

    func addToHistory(item: IMDBItem) {
        // Remove existing entry for same IMDB ID
        history.removeAll { $0.imdbID == item.imdbID }

        let historyItem = WatchHistoryItem.from(item: item)
        history.insert(historyItem, at: 0)

        // Keep only last 50
        if history.count > maxItems {
            history = Array(history.prefix(maxItems))
        }

        saveHistory()
    }

    func removeFromHistory(_ item: WatchHistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        history.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let items = try? JSONDecoder().decode([WatchHistoryItem].self, from: data) else { return }
        history = items
    }
}
