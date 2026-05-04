import Foundation

struct ContentCategory: Identifiable {
    let id = UUID()
    let title: String
    let items: [IMDBItem]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var categories: [ContentCategory] = []
    @Published var heroItem: IMDBItem?
    @Published var isLoading = false

    private let service = IMDBService.shared

    private let categoryData: [(String, [String])] = [
        ("Populer Filmler", ["tt0111161", "tt0068646", "tt0071562", "tt0468569", "tt1375666"]),
        ("Populer Diziler", ["tt0903747", "tt5491994", "tt0944947", "tt7366338", "tt0108778"]),
        ("En Cok Oylanan", ["tt0050083", "tt0167260", "tt0110912", "tt0060196", "tt0120737"]),
        ("Yeni Eklenenler", ["tt6723592", "tt15398776", "tt14230458", "tt1160419", "tt0816692"])
    ]

    func loadContent() async {
        guard categories.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        var loadedCategories: [ContentCategory] = []

        for (title, ids) in categoryData {
            let items = await service.fetchItems(imdbIDs: ids)
            if !items.isEmpty {
                loadedCategories.append(ContentCategory(title: title, items: items))
            }
        }

        categories = loadedCategories

        if let firstCategory = categories.first, let first = firstCategory.items.first {
            heroItem = first
        }
    }
}
