import Foundation

enum DownloadStatus: String, Codable {
    case downloading
    case completed
    case failed
}

struct DownloadItem: Identifiable, Codable {
    let id: String
    let imdbID: String
    let title: String
    let posterURL: String?
    var fileURL: String?
    var progress: Double
    var status: DownloadStatus
    var downloadDate: Date?
    var fileSize: Int64?

    var localFileURL: URL? {
        guard let fileURL else { return nil }
        return URL(fileURLWithPath: fileURL)
    }

    var fileSizeText: String {
        guard let size = fileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var posterImageURL: URL? {
        guard let posterURL else { return nil }
        return URL(string: posterURL)
    }
}
