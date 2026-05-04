import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedItem: DownloadItem?

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Henuz indirilen icerik yok")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Bir film veya dizi izlerken indirme butonuna basin")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(downloadManager.downloads) { item in
                            DownloadRow(item: item)
                                .onTapGesture {
                                    if item.status == .completed {
                                        selectedItem = item
                                    }
                                }
                                .listRowBackground(Color.black)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                downloadManager.deleteDownload(downloadManager.downloads[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Indirilenler")
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .fullScreenCover(item: $selectedItem) { item in
                OfflinePlayerView(item: item)
            }
        }
    }
}

struct DownloadRow: View {
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)

                switch item.status {
                case .downloading:
                    ProgressView(value: item.progress)
                        .tint(Color("AccentColor"))
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .completed:
                    HStack(spacing: 8) {
                        Text(item.fileSizeText)
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let lang = item.subtitleLanguage {
                            HStack(spacing: 2) {
                                Image(systemName: "captions.bubble.fill")
                                    .font(.caption2)
                                Text(lang)
                                    .font(.caption)
                            }
                            .foregroundColor(Color("AccentColor"))
                        }
                        if let date = item.downloadDate {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                case .failed:
                    Text("Indirme basarisiz")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if item.status == .completed {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .padding(.vertical, 4)
    }
}
