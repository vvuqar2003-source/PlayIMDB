import Foundation

final class VideoStreamService {
    static let shared = VideoStreamService()
    private init() {}

    private let session = URLSession.shared

    struct StreamResponse: Codable {
        let status_code: String
        let data: StreamData?
    }

    struct StreamData: Codable {
        let title: String?
        let imdb_id: String?
        let file_name: String?
        let backdrop: String?
        let stream_urls: [String]?
    }

    /// Fetches direct stream URLs for a given IMDB ID
    func fetchStreamURLs(imdbID: String, type: String = "movie") async -> [String] {
        let urlString = "https://streamdata.vaplayer.ru/api.php?imdb=\(imdbID)&type=\(type)"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://brightpathsignals.com/", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(StreamResponse.self, from: data)
            if response.status_code == "200", let urls = response.data?.stream_urls {
                return urls
            }
        } catch {}

        return []
    }

    /// Returns the best (first) m3u8 stream URL
    func getBestStreamURL(imdbID: String, type: String = "movie") async -> String? {
        let urls = await fetchStreamURLs(imdbID: imdbID, type: type)
        return urls.first
    }
}
