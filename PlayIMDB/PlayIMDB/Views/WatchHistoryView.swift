import SwiftUI

struct WatchHistoryView: View {
    @StateObject private var historyManager = WatchHistoryManager.shared
    @State private var showPlayer = false
    @State private var selectedIMDBItem: IMDBItem?
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Henuz izleme gecmisiniz yok")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Bir film veya dizi izlediginizde burada gorunecek")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(historyManager.history) { item in
                            HistoryRow(item: item)
                                .onTapGesture {
                                    let imdbItem = IMDBItem(
                                        id: item.imdbID,
                                        l: item.title,
                                        y: item.year,
                                        s: nil,
                                        q: item.typeText,
                                        i: item.posterURL != nil ? IMDBItem.IMDBImage(
                                            imageUrl: item.posterURL!,
                                            width: 300,
                                            height: 450
                                        ) : nil,
                                        qid: nil
                                    )
                                    selectedIMDBItem = imdbItem
                                    showPlayer = true
                                }
                                .listRowBackground(Color.black)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                historyManager.removeFromHistory(historyManager.history[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Son Izlenenler")
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .toolbar {
                if !historyManager.history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showClearAlert = true
                        } label: {
                            Text("Temizle")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                }
            }
            .alert("Gecmisi Temizle", isPresented: $showClearAlert) {
                Button("Temizle", role: .destructive) {
                    historyManager.clearAll()
                }
                Button("Iptal", role: .cancel) {}
            } message: {
                Text("Tum izleme gecmisiniz silinecek. Emin misiniz?")
            }
            .navigationDestination(isPresented: $showPlayer) {
                if let item = selectedIMDBItem {
                    PlayerView(item: item)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let item: WatchHistoryItem

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

                if let year = item.year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                if let typeText = item.typeText {
                    Text(typeText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text(item.watchDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(Color("AccentColor"))
        }
        .padding(.vertical, 4)
    }
}
