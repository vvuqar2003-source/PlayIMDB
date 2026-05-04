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
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let contentController = WKUserContentController()

        // Comprehensive JS injection that:
        // 1. Intercepts XMLHttpRequest and fetch for .m3u8/.mp4 URLs
        // 2. Monitors HLS.js manifest loading by hooking Hls prototype
        // 3. Watches video element src changes
        // 4. Periodically scans for video elements
        // Runs in ALL frames (mainFrameOnly: false) to catch iframe content
        let js = """
        (function() {
            var sent = {};
            function send(src) {
                if (!src || sent[src]) return;
                var s = src.toLowerCase();
                if (s.indexOf('.m3u8') !== -1 || s.indexOf('.mp4') !== -1 ||
                    s.indexOf('master.m3u8') !== -1 || s.indexOf('index.m3u8') !== -1 ||
                    s.indexOf('playlist') !== -1 || s.indexOf('/hls/') !== -1 ||
                    s.indexOf('mime=video') !== -1 || s.indexOf('.ts') !== -1) {
                    // Prefer m3u8 over ts segments
                    if (s.indexOf('.ts') !== -1 && s.indexOf('.m3u8') === -1) return;
                    sent[src] = true;
                    try { window.webkit.messageHandlers.videoURL.postMessage(src); } catch(e) {}
                }
            }

            // 1. Intercept XMLHttpRequest
            try {
                var xhrOpen = XMLHttpRequest.prototype.open;
                var xhrSend = XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.open = function(m, u) {
                    this._url = u;
                    if (typeof u === 'string') send(u);
                    return xhrOpen.apply(this, arguments);
                };
                XMLHttpRequest.prototype.send = function() {
                    var self = this;
                    this.addEventListener('load', function() {
                        try {
                            if (self._url) send(self._url);
                            // Check if response contains m3u8 URLs
                            var t = self.responseText || '';
                            var matches = t.match(/https?:\\/\\/[^\\s"']+\\.m3u8[^\\s"']*/gi);
                            if (matches) { for (var i = 0; i < matches.length; i++) send(matches[i]); }
                        } catch(e) {}
                    });
                    return xhrSend.apply(this, arguments);
                };
            } catch(e) {}

            // 2. Intercept fetch
            try {
                var origFetch = window.fetch;
                window.fetch = function(input, init) {
                    var u = typeof input === 'string' ? input : (input && input.url ? input.url : '');
                    if (u) send(u);
                    return origFetch.apply(this, arguments).then(function(resp) {
                        try {
                            var url2 = resp.url || '';
                            send(url2);
                        } catch(e) {}
                        return resp;
                    });
                };
            } catch(e) {}

            // 3. Hook HLS.js if loaded
            function hookHls() {
                try {
                    if (window.Hls && !window.Hls._hooked) {
                        window.Hls._hooked = true;
                        var origLoad = window.Hls.prototype.loadSource;
                        window.Hls.prototype.loadSource = function(src) {
                            send(src);
                            return origLoad.apply(this, arguments);
                        };
                    }
                } catch(e) {}
            }

            // 4. Monitor video elements
            function checkVideos() {
                try {
                    document.querySelectorAll('video, video source').forEach(function(el) {
                        send(el.src || el.getAttribute('src') || el.currentSrc || '');
                    });
                } catch(e) {}
                hookHls();
            }

            // 5. MutationObserver
            try {
                new MutationObserver(function() { checkVideos(); }).observe(
                    document.documentElement || document, {childList:true, subtree:true, attributes:true, attributeFilter:['src']}
                );
            } catch(e) {}

            // 6. Periodic check
            checkVideos();
            setInterval(checkVideos, 2000);

            // 7. Listen for postMessage (some players communicate via postMessage)
            window.addEventListener('message', function(e) {
                try {
                    var d = e.data;
                    if (typeof d === 'string') send(d);
                    if (typeof d === 'object' && d) {
                        var vals = JSON.stringify(d);
                        var m = vals.match(/https?:\\/\\/[^"]+\\.m3u8[^"]*/gi);
                        if (m) { for (var i = 0; i < m.length; i++) send(m[i]); }
                    }
                } catch(e) {}
            });
        })();
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
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
        private var bestURL: String?

        init(onVideoURLCaptured: @escaping (String) -> Void) {
            self.onVideoURLCaptured = onVideoURLCaptured
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoURL", let urlString = message.body as? String {
                let lower = urlString.lowercased()
                // Prefer m3u8 master/index over other types
                if lower.contains(".m3u8") {
                    bestURL = urlString
                } else if bestURL == nil && lower.contains(".mp4") {
                    bestURL = urlString
                }
                DispatchQueue.main.async {
                    self.onVideoURLCaptured(self.bestURL ?? urlString)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                checkURL(url)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let url = navigationResponse.response.url?.absoluteString {
                checkURL(url)
            }
            if let mime = navigationResponse.response.mimeType?.lowercased() {
                if mime.contains("mpegurl") || mime.contains("mp4") || mime.contains("video") {
                    if let url = navigationResponse.response.url?.absoluteString {
                        bestURL = url
                        DispatchQueue.main.async { self.onVideoURLCaptured(url) }
                    }
                }
            }
            decisionHandler(.allow)
        }

        private func checkURL(_ url: String) {
            let lower = url.lowercased()
            if lower.contains(".m3u8") || lower.contains(".mp4") {
                if lower.contains(".m3u8") { bestURL = url }
                else if bestURL == nil { bestURL = url }
                DispatchQueue.main.async { self.onVideoURLCaptured(self.bestURL ?? url) }
            }
        }
    }
}
