import Foundation

struct WatchHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let imdbID: String
    let title: String
    let posterURL: String?
    let year: Int?
    var watchDate: Date
    var typeText: String?

    var posterImageURL: URL? {
        guard let posterURL else { return nil }
        return URL(string: posterURL)
    }

    var playURL: URL? {
        URL(string: "https://www.playimdb.com/title/\(imdbID)")
    }

    static func from(item: IMDBItem) -> WatchHistoryItem {
        WatchHistoryItem(
            id: UUID().uuidString,
            imdbID: item.imdbID,
            title: item.title,
            posterURL: item.posterURL?.absoluteString,
            year: item.year,
            watchDate: Date(),
            typeText: item.typeText
        )
    }
}
