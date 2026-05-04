import SwiftUI
import WebKit

struct PlayerView: View {
    let item: IMDBItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var capturedVideoURL: String?
    @State private var showDownloadAlert = false

    var body: some View {
        VStack(spacing: 0) {
            PlayerWebView(
                url: item.playURL!,
                onVideoURLCaptured: { url in
                    capturedVideoURL = url
                }
            )
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
                    if let videoURL = capturedVideoURL {
                        downloadManager.startDownload(
                            videoURL: videoURL,
                            imdbID: item.imdbID,
                            title: item.title,
                            posterURL: item.posterURL?.absoluteString
                        )
                        showDownloadAlert = true
                    }
                } label: {
                    Image(systemName: capturedVideoURL != nil ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(capturedVideoURL != nil ? Color("AccentColor") : .gray)
                }
            }
        }
        .alert("Indirme Basladi", isPresented: $showDownloadAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("\(item.title) indiriliyor. Indirilenler sekmesinden takip edebilirsiniz.")
        }
    }
}

struct PlayerWebView: UIViewRepresentable {
    let url: URL
    let onVideoURLCaptured: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoURLCaptured: onVideoURLCaptured)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        let js = """
        (function() {
            var observer = new MutationObserver(function(mutations) {
                document.querySelectorAll('video source, video').forEach(function(el) {
                    var src = el.src || el.getAttribute('src');
                    if (src && (src.includes('.mp4') || src.includes('.m3u8'))) {
                        window.webkit.messageHandlers.videoURL.postMessage(src);
                    }
                });
            });
            observer.observe(document, { childList: true, subtree: true });

            // Also check immediately
            document.querySelectorAll('video source, video').forEach(function(el) {
                var src = el.src || el.getAttribute('src');
                if (src && (src.includes('.mp4') || src.includes('.m3u8'))) {
                    window.webkit.messageHandlers.videoURL.postMessage(src);
                }
            });
        })();
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "videoURL")

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onVideoURLCaptured: (String) -> Void

        init(onVideoURLCaptured: @escaping (String) -> Void) {
            self.onVideoURLCaptured = onVideoURLCaptured
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoURL", let urlString = message.body as? String {
                DispatchQueue.main.async {
                    self.onVideoURLCaptured(urlString)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
