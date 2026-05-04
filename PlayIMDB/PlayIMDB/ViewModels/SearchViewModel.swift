import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [IMDBItem] = []
    @Published var isSearching = false

    private let service = IMDBService.shared
    private var searchTask: Task<Void, Never>?

    func searchTextChanged() {
        searchTask?.cancel()

        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard currentQuery.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            do {
                let items = try await service.fetchSuggestions(query: currentQuery)
                guard !Task.isCancelled else { return }
                results = items.filter { $0.id.hasPrefix("tt") }
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                isSearching = false
            }
        }
    }
}
