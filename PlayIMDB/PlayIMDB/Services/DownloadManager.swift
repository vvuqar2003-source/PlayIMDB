import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.playimdb.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let saveKey = "PlayIMDB_Downloads"

    private override init() {
        super.init()
        loadDownloads()
    }

    func startDownload(videoURL: String, imdbID: String, title: String, posterURL: String?) {
        guard !downloads.contains(where: { $0.imdbID == imdbID && $0.status == .downloading }) else { return }

        downloads.removeAll { $0.imdbID == imdbID && $0.status == .failed }

        guard let url = URL(string: videoURL) else { return }

        let item = DownloadItem(
            id: UUID().uuidString,
            imdbID: imdbID,
            title: title,
            posterURL: posterURL,
            fileURL: nil,
            progress: 0,
            status: .downloading,
            downloadDate: nil,
            fileSize: nil
        )

        downloads.insert(item, at: 0)
        saveDownloads()

        let task = session.downloadTask(with: url)
        task.taskDescription = item.id
        activeTasks[item.id] = task
        task.resume()
    }

    func deleteDownload(_ item: DownloadItem) {
        if let fileURL = item.localFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        downloads.removeAll { $0.id == item.id }
        activeTasks[item.id]?.cancel()
        activeTasks.removeValue(forKey: item.id)
        saveDownloads()
    }

    private func downloadsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveDownloads() {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        downloads = items
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let itemID = downloadTask.taskDescription else { return }

        let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        let fileName = "\(itemID).mp4"
        let destinationURL = destinationDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0

            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .completed
                    self.downloads[index].fileURL = destinationURL.path
                    self.downloads[index].downloadDate = Date()
                    self.downloads[index].fileSize = fileSize
                    self.downloads[index].progress = 1.0
                    self.activeTasks.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        } catch {
            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .failed
                    self.activeTasks.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let itemID = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].progress = progress
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let itemID = task.taskDescription else { return }

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].status = .failed
                self.activeTasks.removeValue(forKey: itemID)
                self.saveDownloads()
            }
        }
    }
}
