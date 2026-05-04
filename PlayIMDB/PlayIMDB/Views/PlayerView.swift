import SwiftUI
import WebKit

struct PlayerView: View {
    let item: IMDBItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var historyManager = WatchHistoryManager.shared
    @State private var streamURL: String?
    @State private var isFetchingStream = false
    @State private var showDownloadAlert = false
    @State private var showNoVideoAlert = false

    var body: some View {
        VStack(spacing: 0) {
            PlayerWebView(url: item.playURL!)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let videoURL = streamURL {
                        downloadManager.startDownload(
                            videoURL: videoURL,
                            imdbID: item.imdbID,
                            title: item.title,
                            posterURL: item.posterURL?.absoluteString
                        )
                        showDownloadAlert = true
                    } else if isFetchingStream {
                        // still loading, do nothing
                    } else {
                        showNoVideoAlert = true
                    }
                } label: {
                    if isFetchingStream {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: streamURL != nil ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundColor(streamURL != nil ? Color("AccentColor") : .gray)
                    }
                }
            }
        }
        .alert("Indirme Basladi", isPresented: $showDownloadAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("\(item.title) indiriliyor. Indirilenler sekmesinden takip edebilirsiniz.")
        }
        .alert("Video Bulunamadi", isPresented: $showNoVideoAlert) {
            Button("Tekrar Dene") {
                fetchStream()
            }
            Button("Iptal", role: .cancel) {}
        } message: {
            Text("Video linki alinamadi. Tekrar denemek ister misiniz?")
        }
        .onAppear {
            historyManager.addToHistory(item: item)
            fetchStream()
        }
    }

    private func fetchStream() {
        isFetchingStream = true
        Task {
            let type = item.qid == "tvSeries" ? "tv" : "movie"
            let url = await VideoStreamService.shared.getBestStreamURL(imdbID: item.imdbID, type: type)
            streamURL = url
            isFetchingStream = false
        }
    }
}

struct PlayerWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
