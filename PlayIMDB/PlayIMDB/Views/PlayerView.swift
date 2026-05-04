import SwiftUI
import WebKit

struct PlayerView: View {
    let item: IMDBItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var historyManager = WatchHistoryManager.shared
    @State private var capturedVideoURL: String?
    @State private var showDownloadAlert = false
    @State private var showNoVideoAlert = false

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
                    } else {
                        showNoVideoAlert = true
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
        .alert("Video Bulunamadi", isPresented: $showNoVideoAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Henuz video URL'si yakalanamadi. Videoyu oynatmaya baslayin ve tekrar deneyin.")
        }
        .onAppear {
            historyManager.addToHistory(item: item)
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
            var lastSent = '';
            function sendURL(src) {
                if (src && src !== lastSent && (src.includes('.mp4') || src.includes('.m3u8') || src.includes('/video') || src.includes('blob:'))) {
                    lastSent = src;
                    window.webkit.messageHandlers.videoURL.postMessage(src);
                }
            }

            // Watch for video elements
            var observer = new MutationObserver(function(mutations) {
                document.querySelectorAll('video, video source, iframe').forEach(function(el) {
                    var src = el.src || el.getAttribute('src') || el.currentSrc;
                    sendURL(src);
                });
            });
            observer.observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });

            // Check immediately and periodically
            function checkVideos() {
                document.querySelectorAll('video, video source').forEach(function(el) {
                    var src = el.src || el.getAttribute('src') || el.currentSrc;
                    sendURL(src);
                });
            }
            checkVideos();
            setInterval(checkVideos, 2000);

            // Intercept XHR for video URLs
            var origOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                if (typeof url === 'string') { sendURL(url); }
                return origOpen.apply(this, arguments);
            };

            // Intercept fetch for video URLs
            var origFetch = window.fetch;
            window.fetch = function(input) {
                var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
                if (url) { sendURL(url); }
                return origFetch.apply(this, arguments);
            };
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
