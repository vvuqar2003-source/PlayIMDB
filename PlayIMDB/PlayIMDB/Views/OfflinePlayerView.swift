import SwiftUI
import AVKit

struct OfflinePlayerView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var subtitleText: String = ""
    @State private var subtitleEntries: [(start: Double, end: Double, text: String)] = []
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Video dosyasi bulunamadi")
                        .foregroundColor(.gray)
                }
            }

            // Subtitle overlay
            if !subtitleText.isEmpty {
                VStack {
                    Spacer()
                    Text(subtitleText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 80)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                player?.pause()
                timer?.invalidate()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            if item.subtitleLanguage != nil {
                HStack(spacing: 4) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.caption)
                    Text(item.subtitleLanguage ?? "")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding()
            }
        }
        .onAppear {
            setupPlayer()
            loadSubtitles()
        }
        .onDisappear {
            player?.pause()
            player = nil
            timer?.invalidate()
        }
    }

    private func setupPlayer() {
        if let fileURL = item.localFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            player = AVPlayer(url: fileURL)
            player?.play()
        }
    }

    private func loadSubtitles() {
        guard let subURL = item.localSubtitleURL,
              FileManager.default.fileExists(atPath: subURL.path),
              let content = try? String(contentsOf: subURL, encoding: .utf8) else { return }

        subtitleEntries = parseSRT(content)

        // Timer to update subtitle text based on playback position
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            guard let player = player, let currentItem = player.currentItem else { return }
            let currentTime = CMTimeGetSeconds(currentItem.currentTime())

            let matching = subtitleEntries.first { entry in
                currentTime >= entry.start && currentTime <= entry.end
            }
            subtitleText = matching?.text ?? ""
        }
    }

    private func parseSRT(_ content: String) -> [(start: Double, end: Double, text: String)] {
        var entries: [(start: Double, end: Double, text: String)] = []
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard lines.count >= 3 else { continue }

            // Find the timecode line (contains "-->")
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = lines[timeLineIndex]
            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2 else { continue }

            let startTime = parseSRTTime(parts[0].trimmingCharacters(in: .whitespaces))
            let endTime = parseSRTTime(parts[1].trimmingCharacters(in: .whitespaces))

            let textLines = Array(lines[(timeLineIndex + 1)...])
            let text = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            if startTime >= 0 && endTime > startTime && !text.isEmpty {
                entries.append((start: startTime, end: endTime, text: text))
            }
        }

        return entries
    }

    private func parseSRTTime(_ timeString: String) -> Double {
        // Format: 00:01:23,456 or 00:01:23.456
        let cleaned = timeString.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count == 3 else { return -1 }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0

        let secParts = parts[2].components(separatedBy: ".")
        let seconds = Double(secParts[0]) ?? 0
        let milliseconds = secParts.count > 1 ? (Double(secParts[1]) ?? 0) / 1000.0 : 0

        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }
}
