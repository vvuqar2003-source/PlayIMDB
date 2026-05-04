import Foundation

final class SubtitleService {
    static let shared = SubtitleService()
    private init() {}

    private let session = URLSession.shared

    struct SubtitleResult: Codable, Identifiable {
        let SubLanguageID: String
        let SubFileName: String
        let SubDownloadLink: String
        let LanguageName: String
        let ISO639: String?
        let SubFormat: String?

        var id: String { SubDownloadLink }
        var displayName: String { LanguageName }
    }

    func fetchSubtitles(imdbID: String, language: String = "all") async -> [SubtitleResult] {
        let numericID = imdbID.replacingOccurrences(of: "tt", with: "")
        let langPath = language == "all" ? "" : "/sublanguageid-\(language)"
        let urlString = "https://rest.opensubtitles.org/search/imdbid-\(numericID)\(langPath)"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("TemporaryUserAgent", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            let results = try JSONDecoder().decode([SubtitleResult].self, from: data)
            var seen: Set<String> = []
            var unique: [SubtitleResult] = []
            for sub in results {
                if !seen.contains(sub.SubLanguageID) {
                    seen.insert(sub.SubLanguageID)
                    unique.append(sub)
                }
            }
            return unique
        } catch {
            return []
        }
    }

    func downloadSubtitle(sub: SubtitleResult) async -> String? {
        guard let url = URL(string: sub.SubDownloadLink) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("TemporaryUserAgent", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (data, response) = try await session.data(for: request)

            // URLSession automatically decompresses gzip when Accept-Encoding is set
            // But OpenSubtitles returns .gz file, so we might need manual handling
            if let text = String(data: data, encoding: .utf8), text.contains("-->") {
                return text
            }
            if let text = String(data: data, encoding: .isoLatin1), text.contains("-->") {
                return text
            }

            // Try NSData decompression (available on iOS 13+)
            let decompressed = try (data as NSData).decompressed(using: .zlib)
            if let text = String(data: decompressed as Data, encoding: .utf8) {
                return text
            }
            return String(data: decompressed as Data, encoding: .isoLatin1)
        } catch {
            return nil
        }
    }

    func saveSubtitle(content: String, itemID: String, language: String) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileName = "\(itemID)_\(language).srt"
        let fileURL = dir.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
