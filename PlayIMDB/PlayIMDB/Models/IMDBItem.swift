import Foundation

struct IMDBSuggestionResponse: Codable {
    let d: [IMDBItem]?
    let q: String?
    let v: Int?
}

struct IMDBItem: Codable, Identifiable, Hashable {
    let id: String
    let l: String
    let y: Int?
    let s: String?
    let q: String?
    let i: IMDBImage?
    let qid: String?

    var title: String { l }
    var year: Int? { y }
    var subtitle: String? { s }
    var typeText: String? { q }
    var imdbID: String { id }

    var posterURL: URL? {
        guard let urlString = i?.imageUrl else { return nil }
        return URL(string: urlString)
    }

    var playURL: URL? {
        URL(string: "https://www.playimdb.com/title/\(id)")
    }

    struct IMDBImage: Codable, Hashable {
        let imageUrl: String
        let width: Int
        let height: Int
    }
}
