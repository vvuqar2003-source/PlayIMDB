import Foundation

final class IMDBService {
    static let shared = IMDBService()
    private init() {}

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    func fetchSuggestions(query: String) async throws -> [IMDBItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let firstChar = String(trimmed.prefix(1))
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        let urlString = "https://v3.sg.media-imdb.com/suggestion/\(firstChar)/\(encoded).json"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(IMDBSuggestionResponse.self, from: data)
        return response.d ?? []
    }

    func fetchItem(imdbID: String) async throws -> IMDBItem? {
        let items = try await fetchSuggestions(query: imdbID)
        return items.first { $0.id == imdbID }
    }

    func fetchItems(imdbIDs: [String]) async -> [IMDBItem] {
        await withTaskGroup(of: IMDBItem?.self, returning: [IMDBItem].self) { group in
            for imdbID in imdbIDs {
                group.addTask {
                    try? await self.fetchItem(imdbID: imdbID)
                }
            }
            var results: [IMDBItem] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }
}
