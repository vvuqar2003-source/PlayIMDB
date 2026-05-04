import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private var activeDownloads: [String: Task<Void, Never>] = [:]
    private let saveKey = "PlayIMDB_Downloads"

    private override init() {
        super.init()
        loadDownloads()
    }

    func startDownload(videoURL: String, imdbID: String, title: String, posterURL: String?, subtitlePath: String? = nil, subtitleLanguage: String? = nil) {
        guard !downloads.contains(where: { $0.imdbID == imdbID && $0.status == .downloading }) else { return }
        downloads.removeAll { $0.imdbID == imdbID && $0.status == .failed }

        let item = DownloadItem(
            id: UUID().uuidString,
            imdbID: imdbID,
            title: title,
            posterURL: posterURL,
            fileURL: nil,
            subtitleURL: subtitlePath,
            subtitleLanguage: subtitleLanguage,
            progress: 0,
            status: .downloading,
            downloadDate: nil,
            fileSize: nil
        )

        downloads.insert(item, at: 0)
        saveDownloads()

        let task = Task {
            await downloadHLS(itemID: item.id, masterURL: videoURL)
        }
        activeDownloads[item.id] = task
    }

    func cancelDownload(_ item: DownloadItem) {
        activeDownloads[item.id]?.cancel()
        activeDownloads.removeValue(forKey: item.id)
        if let index = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[index].status = .failed
            downloads[index].progress = 0
        }
        saveDownloads()
    }

    func deleteDownload(_ item: DownloadItem) {
        cancelDownload(item)
        if let fileURL = item.localFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let subURL = item.localSubtitleURL {
            try? FileManager.default.removeItem(at: subURL)
        }
        downloads.removeAll { $0.id == item.id }
        saveDownloads()
    }

    func clearCompleted() {
        let completed = downloads.filter { $0.status == .completed }
        for item in completed { deleteDownload(item) }
    }

    func clearAll() {
        for item in downloads { deleteDownload(item) }
    }

    // MARK: - HLS Segment Download

    private func downloadHLS(itemID: String, masterURL: String) async {
        let session = URLSession.shared

        do {
            // 1. Fetch master m3u8
            guard let masterU = URL(string: masterURL) else { throw URLError(.badURL) }
            var req = URLRequest(url: masterU)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (masterData, _) = try await session.data(for: req)
            let masterContent = String(data: masterData, encoding: .utf8) ?? ""

            guard !Task.isCancelled else { return }

            // 2. Parse master — get best quality index URL
            let masterLines = masterContent.components(separatedBy: "\n")
            let indexLines = masterLines.filter { $0.contains("index.m3u8") || $0.contains("list.m3u8") }
            guard let bestIndex = indexLines.last else { throw URLError(.badURL) }

            // Build full URL
            guard let parsed = URLComponents(string: masterURL) else { throw URLError(.badURL) }
            let domain = "\(parsed.scheme ?? "https")://\(parsed.host ?? "")"
            let fullIndexURL: String
            if bestIndex.hasPrefix("http") {
                fullIndexURL = bestIndex
            } else {
                fullIndexURL = domain + bestIndex
            }

            // 3. Fetch index m3u8 — get segment list
            guard let indexU = URL(string: fullIndexURL) else { throw URLError(.badURL) }
            var req2 = URLRequest(url: indexU)
            req2.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (indexData, _) = try await session.data(for: req2)
            let indexContent = String(data: indexData, encoding: .utf8) ?? ""

            let segments = indexContent.components(separatedBy: "\n")
                .filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard !segments.isEmpty else { throw URLError(.badURL) }
            guard !Task.isCancelled else { return }

            // 4. Prepare destination file
            let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destFile = destDir.appendingPathComponent("\(itemID).mp4")
            FileManager.default.createFile(atPath: destFile.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: destFile)
            defer { try? fileHandle.close() }

            // 5. Download segments one by one
            let totalSegments = segments.count
            for (i, segURL) in segments.enumerated() {
                guard !Task.isCancelled else {
                    try? fileHandle.close()
                    try? FileManager.default.removeItem(at: destFile)
                    return
                }

                let fullSegURL: String
                if segURL.hasPrefix("http") {
                    fullSegURL = segURL
                } else {
                    fullSegURL = domain + segURL
                }

                guard let segU = URL(string: fullSegURL) else { continue }

                var segReq = URLRequest(url: segU)
                segReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

                // Retry up to 3 times per segment
                var segData: Data?
                for attempt in 0..<3 {
                    do {
                        let (data, _) = try await session.data(for: segReq)
                        if data.count > 0 {
                            segData = data
                            break
                        }
                    } catch {
                        if attempt < 2 {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                        }
                    }
                }

                if let data = segData {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }

                // Update progress
                let progress = Double(i + 1) / Double(totalSegments)
                await MainActor.run {
                    if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                        self.downloads[index].progress = progress
                    }
                }
            }

            // 6. Done — update status
            try? fileHandle.close()
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destFile.path)[.size] as? Int64) ?? 0

            await MainActor.run {
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .completed
                    self.downloads[index].fileURL = destFile.path
                    self.downloads[index].downloadDate = Date()
                    self.downloads[index].fileSize = fileSize
                    self.downloads[index].progress = 1.0
                    self.activeDownloads.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        } catch {
            await MainActor.run {
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .failed
                    self.activeDownloads.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveDownloads() {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        downloads = items
        for i in downloads.indices {
            if downloads[i].status == .downloading {
                downloads[i].status = .failed
            }
        }
        saveDownloads()
    }
}
