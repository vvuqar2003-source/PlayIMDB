import Foundation
import AVFoundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private var hlsSession: AVAssetDownloadURLSession!
    private var activeTasks: [String: AVAggregateAssetDownloadTask] = [:]
    private var regularSession: URLSession!
    private var regularTasks: [String: URLSessionDownloadTask] = [:]

    private let saveKey = "PlayIMDB_Downloads"

    private override init() {
        super.init()

        // HLS download session
        let hlsConfig = URLSessionConfiguration.background(withIdentifier: "com.playimdb.hls")
        hlsConfig.isDiscretionary = false
        hlsConfig.sessionSendsLaunchEvents = true
        hlsSession = AVAssetDownloadURLSession(
            configuration: hlsConfig,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )

        // Regular download session for direct mp4
        let regConfig = URLSessionConfiguration.background(withIdentifier: "com.playimdb.download")
        regConfig.isDiscretionary = false
        regularSession = URLSession(configuration: regConfig, delegate: self, delegateQueue: nil)

        loadDownloads()
    }

    func startDownload(videoURL: String, imdbID: String, title: String, posterURL: String?, subtitlePath: String? = nil, subtitleLanguage: String? = nil) {
        guard !downloads.contains(where: { $0.imdbID == imdbID && $0.status == .downloading }) else { return }

        // Remove previous failed
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

        let lowered = videoURL.lowercased()
        if lowered.contains(".m3u8") || lowered.contains("master.m3u8") || lowered.contains("index.m3u8") || lowered.contains("list.m3u8") {
            startHLSDownload(url: videoURL, itemID: item.id, title: title)
        } else {
            startDirectDownload(url: videoURL, itemID: item.id)
        }
    }

    func cancelDownload(_ item: DownloadItem) {
        activeTasks[item.id]?.cancel()
        activeTasks.removeValue(forKey: item.id)
        regularTasks[item.id]?.cancel()
        regularTasks.removeValue(forKey: item.id)

        if let index = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[index].status = .failed
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
        for item in completed {
            deleteDownload(item)
        }
    }

    func clearAll() {
        let all = downloads
        for item in all {
            deleteDownload(item)
        }
    }

    // MARK: - HLS Download

    private func startHLSDownload(url: String, itemID: String, title: String) {
        guard let videoURL = URL(string: url) else { return }
        let asset = AVURLAsset(url: videoURL)

        guard let task = hlsSession.aggregateAssetDownloadTask(
            with: asset,
            mediaSelections: [asset.preferredMediaSelection],
            assetTitle: title,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 0]
        ) else {
            // Fallback to direct download
            startDirectDownload(url: url, itemID: itemID)
            return
        }

        task.taskDescription = itemID
        activeTasks[itemID] = task
        task.resume()
    }

    // MARK: - Direct Download (mp4 fallback)

    private func startDirectDownload(url: String, itemID: String) {
        guard let videoURL = URL(string: url) else { return }
        let task = regularSession.downloadTask(with: videoURL)
        task.taskDescription = itemID
        regularTasks[itemID] = task
        task.resume()
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
        // Reset any stuck downloading items
        for i in downloads.indices {
            if downloads[i].status == .downloading {
                downloads[i].status = .failed
            }
        }
        saveDownloads()
    }
}

// MARK: - AVAssetDownloadDelegate (HLS)

extension DownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, willDownloadTo location: URL) {
        let itemID = aggregateAssetDownloadTask.taskDescription ?? ""
        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].fileURL = location.relativePath
            }
        }
    }

    func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        let itemID = aggregateAssetDownloadTask.taskDescription ?? ""

        var totalLoaded: Double = 0
        for value in loadedTimeRanges {
            let loaded = value.timeRangeValue
            totalLoaded += CMTimeGetSeconds(loaded.duration)
        }
        let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        let progress = expected > 0 ? min(totalLoaded / expected, 1.0) : 0

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].progress = progress
            }
        }
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        let itemID = assetDownloadTask.taskDescription ?? ""
        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].fileURL = location.relativePath
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let itemID = task.taskDescription ?? ""

        if let _ = task as? AVAggregateAssetDownloadTask {
            Task { @MainActor in
                self.activeTasks.removeValue(forKey: itemID)
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    if let error = error as? NSError, error.code != NSURLErrorCancelled {
                        self.downloads[index].status = .failed
                    } else if error == nil {
                        self.downloads[index].status = .completed
                        self.downloads[index].downloadDate = Date()
                        self.downloads[index].progress = 1.0
                        // Calculate file size
                        if let path = self.downloads[index].fileURL {
                            let url = URL(fileURLWithPath: NSHomeDirectory() + "/" + path)
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            self.downloads[index].fileSize = size
                        }
                    }
                    self.saveDownloads()
                }
            }
            return
        }

        // Regular download task completion
        if let _ = task as? URLSessionDownloadTask {
            guard let error else { return }
            Task { @MainActor in
                self.regularTasks.removeValue(forKey: itemID)
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    if (error as NSError).code != NSURLErrorCancelled {
                        self.downloads[index].status = .failed
                    }
                    self.saveDownloads()
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate (Direct mp4)

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
                    self.regularTasks.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        } catch {
            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .failed
                    self.regularTasks.removeValue(forKey: itemID)
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
}
