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
    @State private var showSubtitlePicker = false
    @State private var availableSubtitles: [SubtitleService.SubtitleResult] = []
    @State private var selectedSubtitle: SubtitleService.SubtitleResult?
    @State private var isLoadingSubs = false

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
                HStack(spacing: 16) {
                    // Subtitle picker button
                    Button {
                        showSubtitlePicker = true
                    } label: {
                        Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                            .foregroundColor(selectedSubtitle != nil ? Color("AccentColor") : .white)
                    }

                    // Download button
                    Button {
                        if let videoURL = streamURL {
                            startDownloadWithSubtitle(videoURL: videoURL)
                        } else if isFetchingStream {
                            // still loading
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
        }
        .alert("Indirme Basladi", isPresented: $showDownloadAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            let subInfo = selectedSubtitle != nil ? " (\(selectedSubtitle!.displayName) altyazili)" : ""
            Text("\(item.title)\(subInfo) indiriliyor. Indirilenler sekmesinden takip edebilirsiniz.")
        }
        .alert("Video Bulunamadi", isPresented: $showNoVideoAlert) {
            Button("Tekrar Dene") { fetchStream() }
            Button("Iptal", role: .cancel) {}
        } message: {
            Text("Video linki alinamadi. Tekrar denemek ister misiniz?")
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerView(
                subtitles: availableSubtitles,
                selected: $selectedSubtitle,
                isLoading: isLoadingSubs
            )
        }
        .onAppear {
            historyManager.addToHistory(item: item)
            fetchStream()
            fetchSubtitles()
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

    private func fetchSubtitles() {
        isLoadingSubs = true
        Task {
            let subs = await SubtitleService.shared.fetchSubtitles(imdbID: item.imdbID)
            availableSubtitles = subs
            // Auto-select Turkish if available
            if let turSub = subs.first(where: { $0.SubLanguageID == "tur" }) {
                selectedSubtitle = turSub
            }
            isLoadingSubs = false
        }
    }

    private func startDownloadWithSubtitle(videoURL: String) {
        Task {
            var subtitlePath: String? = nil
            var subtitleLang: String? = nil

            // Download subtitle if selected
            if let sub = selectedSubtitle {
                if let content = await SubtitleService.shared.downloadSubtitle(sub: sub) {
                    let itemID = UUID().uuidString
                    if let savedURL = SubtitleService.shared.saveSubtitle(content: content, itemID: item.imdbID, language: sub.SubLanguageID) {
                        subtitlePath = savedURL.path
                        subtitleLang = sub.displayName
                    }
                }
            }

            downloadManager.startDownload(
                videoURL: videoURL,
                imdbID: item.imdbID,
                title: item.title,
                posterURL: item.posterURL?.absoluteString,
                subtitlePath: subtitlePath,
                subtitleLanguage: subtitleLang
            )
            showDownloadAlert = true
        }
    }
}

// MARK: - Subtitle Picker Sheet

struct SubtitlePickerView: View {
    let subtitles: [SubtitleService.SubtitleResult]
    @Binding var selected: SubtitleService.SubtitleResult?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("Altyazilar yukleniyor...")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                } else if subtitles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "captions.bubble")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Altyazi bulunamadi")
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        // No subtitle option
                        Button {
                            selected = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("Altyazisiz")
                                    .foregroundColor(.white)
                                Spacer()
                                if selected == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("AccentColor"))
                                }
                            }
                        }
                        .listRowBackground(Color.black)

                        ForEach(subtitles) { sub in
                            Button {
                                selected = sub
                                dismiss()
                            } label: {
                                HStack {
                                    Text(sub.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selected?.id == sub.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color("AccentColor"))
                                    }
                                }
                            }
                            .listRowBackground(Color.black)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Altyazi Sec")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Color("AccentColor"))
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - WebView

struct PlayerWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

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
