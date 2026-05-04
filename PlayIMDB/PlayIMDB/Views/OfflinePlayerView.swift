import SwiftUI
import AVKit

struct OfflinePlayerView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

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
        }
        .overlay(alignment: .topLeading) {
            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            if let fileURL = item.localFileURL,
               FileManager.default.fileExists(atPath: fileURL.path) {
                player = AVPlayer(url: fileURL)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
