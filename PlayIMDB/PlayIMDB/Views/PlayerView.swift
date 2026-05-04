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
            Text("Videoyu oynatmaya baslayin, ardindan tekrar indirme butonuna basin.")
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

        // JS that runs in ALL frames (mainFrameOnly: false)
        // This catches video elements in the main page AND inside iframes (same-origin only)
        // For cross-origin iframes, we rely on network request interception
        let js = """
        (function() {
            var lastSent = '';
            function sendURL(src) {
                if (!src || src === lastSent) return;
                if (src.includes('.m3u8') || src.includes('.mp4') || src.includes('/playlist') || src.includes('/master') || src.includes('/video')) {
                    lastSent = src;
                    try { window.webkit.messageHandlers.videoURL.postMessage(src); } catch(e) {}
                }
            }

            // Monitor video elements
            function checkVideos() {
                try {
                    document.querySelectorAll('video, video source, iframe').forEach(function(el) {
                        sendURL(el.src || el.getAttribute('src') || el.currentSrc || '');
                    });
                } catch(e) {}
            }

            // MutationObserver for dynamic content
            try {
                var obs = new MutationObserver(function() { checkVideos(); });
                obs.observe(document.documentElement || document.body || document, {
                    childList: true, subtree: true, attributes: true, attributeFilter: ['src']
                });
            } catch(e) {}

            // Intercept XMLHttpRequest
            try {
                var origOpen = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, url) {
                    if (typeof url === 'string') sendURL(url);
                    return origOpen.apply(this, arguments);
                };
            } catch(e) {}

            // Intercept fetch
            try {
                var origFetch = window.fetch;
                window.fetch = function(input) {
                    var u = typeof input === 'string' ? input : (input && input.url ? input.url : '');
                    sendURL(u);
                    return origFetch.apply(this, arguments);
                };
            } catch(e) {}

            // Periodically check
            checkVideos();
            setInterval(checkVideos, 1500);
        })();
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "videoURL")

        config.userContentController = contentController

        // Allow all media types in iframes
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

        // Intercept ALL navigation requests — this catches cross-origin iframe loads and video resource requests
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                checkForVideoURL(url)
            }
            decisionHandler(.allow)
        }

        // Intercept ALL responses — catches .m3u8 and .mp4 content types from any frame
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let url = navigationResponse.response.url?.absoluteString {
                checkForVideoURL(url)
            }

            // Also check MIME type
            if let mimeType = navigationResponse.response.mimeType {
                if mimeType.contains("mpegurl") || mimeType.contains("mp4") || mimeType.contains("video") {
                    if let url = navigationResponse.response.url?.absoluteString {
                        DispatchQueue.main.async {
                            self.onVideoURLCaptured(url)
                        }
                    }
                }
            }

            decisionHandler(.allow)
        }

        private func checkForVideoURL(_ url: String) {
            let lowered = url.lowercased()
            if lowered.contains(".m3u8") || lowered.contains(".mp4") ||
               lowered.contains("/playlist") || lowered.contains("/master.m3u8") ||
               lowered.contains("mime=video") {
                DispatchQueue.main.async {
                    self.onVideoURLCaptured(url)
                }
            }
        }
    }
}
