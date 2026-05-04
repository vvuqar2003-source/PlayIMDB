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
    @State private var allSubtitlesForLanguage: [SubtitleService.SubtitleResult] = []
    @State private var selectedSubtitle: SubtitleService.SubtitleResult?
    @State private var isLoadingSubs = false
    @State private var showLanguageDetail = false
    @State private var selectedLanguage: String?

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
                    Button { showSubtitlePicker = true } label: {
                        Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                            .foregroundColor(selectedSubtitle != nil ? Color("AccentColor") : .white)
                    }
                    Button {
                        if let videoURL = streamURL {
                            startDownloadWithSubtitle(videoURL: videoURL)
                        } else if !isFetchingStream {
                            showNoVideoAlert = true
                        }
                    } label: {
                        if isFetchingStream {
                            ProgressView().scaleEffect(0.7).tint(.white)
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
            Text("\(item.title)\(subInfo) indiriliyor.")
        }
        .alert("Video Bulunamadi", isPresented: $showNoVideoAlert) {
            Button("Tekrar Dene") { fetchStream() }
            Button("Iptal", role: .cancel) {}
        } message: {
            Text("Video linki alinamadi. Tekrar denemek ister misiniz?")
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerView(
                languages: availableSubtitles,
                allSubtitles: allSubtitlesForLanguage,
                selected: $selectedSubtitle,
                isLoading: isLoadingSubs,
                imdbID: item.imdbID
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
            streamURL = await VideoStreamService.shared.getBestStreamURL(imdbID: item.imdbID, type: type)
            isFetchingStream = false
        }
    }

    private func fetchSubtitles() {
        isLoadingSubs = true
        Task {
            let all = await SubtitleService.shared.fetchAllSubtitles(imdbID: item.imdbID)
            allSubtitlesForLanguage = all
            availableSubtitles = await SubtitleService.shared.fetchSubtitles(imdbID: item.imdbID)
            if let turSub = availableSubtitles.first(where: { $0.SubLanguageID == "tur" }) {
                selectedSubtitle = turSub
            }
            isLoadingSubs = false
        }
    }

    private func startDownloadWithSubtitle(videoURL: String) {
        Task {
            var subtitlePath: String? = nil
            var subtitleLang: String? = nil
            if let sub = selectedSubtitle {
                if let content = await SubtitleService.shared.downloadSubtitle(sub: sub) {
                    if let savedURL = SubtitleService.shared.saveSubtitle(content: content, itemID: item.imdbID, language: sub.SubLanguageID) {
                        subtitlePath = savedURL.path
                        subtitleLang = sub.displayName
                    }
                }
            }
            downloadManager.startDownload(
                videoURL: videoURL, imdbID: item.imdbID, title: item.title,
                posterURL: item.posterURL?.absoluteString,
                subtitlePath: subtitlePath, subtitleLanguage: subtitleLang
            )
            showDownloadAlert = true
        }
    }
}

// MARK: - Subtitle Picker (Languages → sub-list with ratings)

struct SubtitlePickerView: View {
    let languages: [SubtitleService.SubtitleResult]
    let allSubtitles: [SubtitleService.SubtitleResult]
    @Binding var selected: SubtitleService.SubtitleResult?
    let isLoading: Bool
    let imdbID: String
    @Environment(\.dismiss) private var dismiss
    @State private var expandedLanguage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView().tint(.white)
                        Text("Altyazilar yukleniyor...").foregroundColor(.gray).padding(.top, 8)
                    }
                } else if languages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "captions.bubble").font(.largeTitle).foregroundColor(.gray)
                        Text("Altyazi bulunamadi").foregroundColor(.gray)
                    }
                } else {
                    List {
                        // No subtitle
                        Button {
                            selected = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("Altyazisiz").foregroundColor(.white)
                                Spacer()
                                if selected == nil {
                                    Image(systemName: "checkmark").foregroundColor(Color("AccentColor"))
                                }
                            }
                        }
                        .listRowBackground(Color.black)

                        ForEach(languages) { lang in
                            let subsForLang = allSubtitles.filter { $0.SubLanguageID == lang.SubLanguageID }
                                .sorted { $0.rating > $1.rating }
                            let count = subsForLang.count

                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedLanguage == lang.SubLanguageID },
                                set: { expandedLanguage = $0 ? lang.SubLanguageID : nil }
                            )) {
                                ForEach(subsForLang) { sub in
                                    Button {
                                        selected = sub
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(sub.releaseName)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            HStack(spacing: 12) {
                                                // Rating
                                                HStack(spacing: 2) {
                                                    Image(systemName: "star.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.yellow)
                                                    Text(String(format: "%.1f", sub.rating))
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }

                                                // Downloads
                                                HStack(spacing: 2) {
                                                    Image(systemName: "arrow.down.circle")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                    Text("\(sub.downloadCount)")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }

                                                // Compatibility badge
                                                Text(sub.compatibilityScore)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(compatibilityBgColor(sub))
                                                    .cornerRadius(4)
                                                    .foregroundColor(.white)

                                                Spacer()

                                                if selected?.id == sub.id {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(Color("AccentColor"))
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .listRowBackground(Color(.systemGray6).opacity(0.15))
                                }
                            } label: {
                                HStack {
                                    Text(lang.displayName)
                                        .foregroundColor(.white)
                                        .font(.body)
                                    Text("(\(count))")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Spacer()
                                    if selected?.SubLanguageID == lang.SubLanguageID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color("AccentColor"))
                                    }
                                }
                            }
                            .listRowBackground(Color.black)
                            .tint(.gray)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Altyazi Sec")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }.foregroundColor(Color("AccentColor"))
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
        }
        .presentationDetents([.large])
    }

    private func compatibilityBgColor(_ sub: SubtitleService.SubtitleResult) -> Color {
        if sub.rating >= 8 { return .green.opacity(0.7) }
        if sub.rating >= 6 { return .yellow.opacity(0.5) }
        return .gray.opacity(0.4)
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
