import Foundation

final class SubtitleService {
    static let shared = SubtitleService()
    private init() {}

    private let session = URLSession.shared

    struct SubtitleResult: Codable, Identifiable, Hashable {
        let SubLanguageID: String
        let SubFileName: String
        let SubDownloadLink: String
        let LanguageName: String
        let ISO639: String?
        let SubFormat: String?
        let SubRating: String?
        let SubDownloadsCnt: String?
        let MatchedBy: String?
        let MovieReleaseName: String?

        var id: String { SubDownloadLink }
        var displayName: String { LanguageName }
        var rating: Double { Double(SubRating ?? "0") ?? 0 }
        var downloadCount: Int { Int(SubDownloadsCnt ?? "0") ?? 0 }
        var releaseName: String { MovieReleaseName ?? SubFileName }

        var compatibilityScore: String {
            if rating >= 8 { return "Mukemmel" }
            if rating >= 6 { return "Iyi" }
            if rating >= 4 { return "Orta" }
            if downloadCount > 10000 { return "Populer" }
            return "Normal"
        }

        var compatibilityColor: String {
            if rating >= 8 { return "green" }
            if rating >= 6 { return "yellow" }
            return "gray"
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SubtitleResult, rhs: SubtitleResult) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Fetch ALL subtitles for a given IMDB ID (no dedup — show all per language)
    func fetchAllSubtitles(imdbID: String, language: String = "all") async -> [SubtitleResult] {
        let numericID = imdbID.replacingOccurrences(of: "tt", with: "")
        let langPath = language == "all" ? "" : "/sublanguageid-\(language)"
        let urlString = "https://rest.opensubtitles.org/search/imdbid-\(numericID)\(langPath)"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("TemporaryUserAgent", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            let results = try JSONDecoder().decode([SubtitleResult].self, from: data)
            return results
        } catch {
            return []
        }
    }

    /// Fetch subtitles deduped by language (one per language, best rated)
    func fetchSubtitles(imdbID: String, language: String = "all") async -> [SubtitleResult] {
        let all = await fetchAllSubtitles(imdbID: imdbID, language: language)
        var seen: Set<String> = []
        var unique: [SubtitleResult] = []
        // Sort by rating first so we keep the best
        let sorted = all.sorted { $0.rating > $1.rating }
        for sub in sorted {
            if !seen.contains(sub.SubLanguageID) {
                seen.insert(sub.SubLanguageID)
                unique.append(sub)
            }
        }
        return unique
    }

    func downloadSubtitle(sub: SubtitleResult) async -> String? {
        guard let url = URL(string: sub.SubDownloadLink) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("TemporaryUserAgent", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)

            if let text = String(data: data, encoding: .utf8), text.contains("-->") {
                return text
            }
            if let text = String(data: data, encoding: .isoLatin1), text.contains("-->") {
                return text
            }

            // Try decompression
            if let decompressed = try? (data as NSData).decompressed(using: .zlib) as Data {
                if let text = String(data: decompressed, encoding: .utf8) { return text }
                return String(data: decompressed, encoding: .isoLatin1)
            }

            return nil
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
