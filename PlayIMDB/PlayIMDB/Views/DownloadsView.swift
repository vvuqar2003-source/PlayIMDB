import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedItem: DownloadItem?
    @State private var showClearAlert = false

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
                            DownloadRow(item: item, onCancel: {
                                downloadManager.cancelDownload(item)
                            })
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
            .toolbar {
                if !downloadManager.downloads.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showClearAlert = true
                            } label: {
                                Label("Tumu Temizle", systemImage: "trash")
                            }

                            Button {
                                downloadManager.clearCompleted()
                            } label: {
                                Label("Tamamlananlari Temizle", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                }
            }
            .alert("Tumu Temizle", isPresented: $showClearAlert) {
                Button("Temizle", role: .destructive) {
                    downloadManager.clearAll()
                }
                Button("Iptal", role: .cancel) {}
            } message: {
                Text("Tum indirmeler silinecek. Emin misiniz?")
            }
            .fullScreenCover(item: $selectedItem) { item in
                OfflinePlayerView(item: item)
            }
        }
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    var onCancel: (() -> Void)?

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
                    HStack {
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        // Cancel button
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
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
