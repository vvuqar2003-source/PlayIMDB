# PlayIMDB iOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Netflix-style iOS app that browses IMDB content, plays videos in-app via WKWebView (playimdb.com), and supports video downloading for offline viewing.

**Architecture:** MVVM with SwiftUI views, async/await network layer, WKWebView for in-app playback, URLSession background downloads for offline. TabView with two tabs: Kesfet (browse/search) and Indirilenler (downloads).

**Tech Stack:** SwiftUI, WebKit (WKWebView), AVKit (AVPlayer), URLSession, Swift Concurrency (async/await), iOS 16+

---

## File Structure

```
PlayIMDB/
├── PlayIMDB.xcodeproj/
│   └── project.pbxproj
├── PlayIMDB/
│   ├── PlayIMDBApp.swift              — App entry point, TabView root
│   ├── Models/
│   │   ├── IMDBItem.swift             — Codable model for IMDB suggestion API response
│   │   └── DownloadItem.swift         — Model for downloaded video metadata
│   ├── Services/
│   │   ├── IMDBService.swift          — Network layer for IMDB suggestion API
│   │   └── DownloadManager.swift      — Video download manager with URL interception
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift        — Loads curated categories via TaskGroup
│   │   └── SearchViewModel.swift      — Debounced search with IMDB suggestions
│   ├── Views/
│   │   ├── ContentView.swift          — Tab 1: NavigationStack + searchable + Home/Search toggle
│   │   ├── HomeView.swift             — Vertical scroll: HeroView + 4x CategoryRow
│   │   ├── HeroView.swift             — Full-width featured banner with gradient
│   │   ├── CategoryRow.swift          — Section title + horizontal scroll of PosterCards
│   │   ├── PosterCard.swift           — 120x180 poster with rounded corners + shadow
│   │   ├── SearchResultRow.swift      — Single search result row (poster + title + year)
│   │   ├── PlayerView.swift           — WKWebView player + download button
│   │   ├── DownloadsView.swift        — Tab 2: list of downloaded videos
│   │   └── OfflinePlayerView.swift    — AVPlayer for local video playback
│   ├── Assets.xcassets/
│   │   ├── Contents.json
│   │   ├── AccentColor.colorset/
│   │   │   └── Contents.json
│   │   └── AppIcon.appiconset/
│   │       └── Contents.json
│   └── Info.plist
├── .github/
│   └── workflows/
│       └── build.yml
```

---

### Task 1: Project Scaffolding & Xcode Project

**Files:**
- Create: `PlayIMDB/PlayIMDB.xcodeproj/project.pbxproj`
- Create: `PlayIMDB/PlayIMDB/PlayIMDBApp.swift`
- Create: `PlayIMDB/PlayIMDB/Assets.xcassets/Contents.json`
- Create: `PlayIMDB/PlayIMDB/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `PlayIMDB/PlayIMDB/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `PlayIMDB/PlayIMDB/Info.plist`

- [ ] **Step 1: Create the Assets.xcassets/Contents.json**

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Create AccentColor.colorset/Contents.json**

Red accent (#E50914):

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x14",
          "green" : "0x09",
          "red" : "0xE5"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Create AppIcon.appiconset/Contents.json**

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleDisplayName</key>
    <string>PlayIMDB</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string>AccentColor</string>
    </dict>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIUserInterfaceStyle</key>
    <string>Dark</string>
</dict>
</plist>
```

- [ ] **Step 5: Create PlayIMDBApp.swift**

Minimal app entry with a placeholder TabView:

```swift
import SwiftUI

@main
struct PlayIMDBApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Text("Kesfet")
                    .tabItem {
                        Label("Kesfet", systemImage: "film")
                    }
                Text("Indirilenler")
                    .tabItem {
                        Label("Indirilenler", systemImage: "arrow.down.circle")
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 6: Create project.pbxproj**

Generate a complete Xcode project file that:
- Bundle ID: `com.playimdb.app`
- Deployment target: iOS 16.0
- Swift version: 5.0
- Includes all source files and asset catalogs
- INFOPLIST_FILE set to `PlayIMDB/Info.plist`
- References all files in the project structure
- Has a scheme named `PlayIMDB`

The pbxproj must include file references for every `.swift` file listed in the File Structure above (even though they don't exist yet — they'll be created in subsequent tasks). This avoids needing to modify the pbxproj after every task.

Full list of source files to reference:
1. `PlayIMDB/PlayIMDBApp.swift`
2. `PlayIMDB/Models/IMDBItem.swift`
3. `PlayIMDB/Models/DownloadItem.swift`
4. `PlayIMDB/Services/IMDBService.swift`
5. `PlayIMDB/Services/DownloadManager.swift`
6. `PlayIMDB/ViewModels/HomeViewModel.swift`
7. `PlayIMDB/ViewModels/SearchViewModel.swift`
8. `PlayIMDB/Views/ContentView.swift`
9. `PlayIMDB/Views/HomeView.swift`
10. `PlayIMDB/Views/HeroView.swift`
11. `PlayIMDB/Views/CategoryRow.swift`
12. `PlayIMDB/Views/PosterCard.swift`
13. `PlayIMDB/Views/SearchResultRow.swift`
14. `PlayIMDB/Views/PlayerView.swift`
15. `PlayIMDB/Views/DownloadsView.swift`
16. `PlayIMDB/Views/OfflinePlayerView.swift`

Asset catalogs:
1. `PlayIMDB/Assets.xcassets`

Info.plist:
1. `PlayIMDB/Info.plist`

Frameworks to link: SwiftUI, WebKit, AVKit

- [ ] **Step 7: Commit**

```bash
git init
git add -A
git commit -m "feat: scaffold PlayIMDB Xcode project with assets and Info.plist"
```

---

### Task 2: IMDBItem Model

**Files:**
- Create: `PlayIMDB/PlayIMDB/Models/IMDBItem.swift`

- [ ] **Step 1: Create IMDBItem.swift**

```swift
import Foundation

struct IMDBSuggestionResponse: Codable {
    let d: [IMDBItem]?
    let q: String?
    let v: Int?
}

struct IMDBItem: Codable, Identifiable, Hashable {
    let id: String
    let l: String
    let y: Int?
    let s: String?
    let q: String?
    let i: IMDBImage?
    let qid: String?

    var title: String { l }
    var year: Int? { y }
    var subtitle: String? { s }
    var typeText: String? { q }
    var imdbID: String { id }

    var posterURL: URL? {
        guard let urlString = i?.imageUrl else { return nil }
        return URL(string: urlString)
    }

    var playURL: URL? {
        URL(string: "https://www.playimdb.com/title/\(id)")
    }

    struct IMDBImage: Codable, Hashable {
        let imageUrl: String
        let width: Int
        let height: Int
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Models/IMDBItem.swift
git commit -m "feat: add IMDBItem and IMDBSuggestionResponse models"
```

---

### Task 3: IMDBService Network Layer

**Files:**
- Create: `PlayIMDB/PlayIMDB/Services/IMDBService.swift`

- [ ] **Step 1: Create IMDBService.swift**

```swift
import Foundation

final class IMDBService {
    static let shared = IMDBService()
    private init() {}

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    func fetchSuggestions(query: String) async throws -> [IMDBItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let firstChar = String(trimmed.prefix(1))
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        let urlString = "https://v3.sg.media-imdb.com/suggestion/\(firstChar)/\(encoded).json"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(IMDBSuggestionResponse.self, from: data)
        return response.d ?? []
    }

    func fetchItem(imdbID: String) async throws -> IMDBItem? {
        let items = try await fetchSuggestions(query: imdbID)
        return items.first { $0.id == imdbID }
    }

    func fetchItems(imdbIDs: [String]) async -> [IMDBItem] {
        await withTaskGroup(of: IMDBItem?.self, returning: [IMDBItem].self) { group in
            for imdbID in imdbIDs {
                group.addTask {
                    try? await self.fetchItem(imdbID: imdbID)
                }
            }
            var results: [IMDBItem] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Services/IMDBService.swift
git commit -m "feat: add IMDBService with suggestion API and batch fetch"
```

---

### Task 4: HomeViewModel

**Files:**
- Create: `PlayIMDB/PlayIMDB/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: Create HomeViewModel.swift**

```swift
import Foundation

struct ContentCategory: Identifiable {
    let id = UUID()
    let title: String
    let items: [IMDBItem]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var categories: [ContentCategory] = []
    @Published var heroItem: IMDBItem?
    @Published var isLoading = false

    private let service = IMDBService.shared

    private let categoryData: [(String, [String])] = [
        ("Populer Filmler", ["tt0111161", "tt0068646", "tt0071562", "tt0468569", "tt1375666"]),
        ("Populer Diziler", ["tt0903747", "tt5491994", "tt0944947", "tt7366338", "tt0108778"]),
        ("En Cok Oylanan", ["tt0050083", "tt0167260", "tt0110912", "tt0060196", "tt0120737"]),
        ("Yeni Eklenenler", ["tt6723592", "tt15398776", "tt14230458", "tt1160419", "tt0816692"])
    ]

    func loadContent() async {
        guard categories.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        var loadedCategories: [ContentCategory] = []

        for (title, ids) in categoryData {
            let items = await service.fetchItems(imdbIDs: ids)
            if !items.isEmpty {
                loadedCategories.append(ContentCategory(title: title, items: items))
            }
        }

        categories = loadedCategories

        if let firstCategory = categories.first, let first = firstCategory.items.first {
            heroItem = first
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/ViewModels/HomeViewModel.swift
git commit -m "feat: add HomeViewModel with curated category loading"
```

---

### Task 5: SearchViewModel

**Files:**
- Create: `PlayIMDB/PlayIMDB/ViewModels/SearchViewModel.swift`

- [ ] **Step 1: Create SearchViewModel.swift**

```swift
import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [IMDBItem] = []
    @Published var isSearching = false

    private let service = IMDBService.shared
    private var searchTask: Task<Void, Never>?

    func searchTextChanged() {
        searchTask?.cancel()

        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard currentQuery.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            do {
                let items = try await service.fetchSuggestions(query: currentQuery)
                guard !Task.isCancelled else { return }
                results = items.filter { $0.id.hasPrefix("tt") }
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                isSearching = false
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/ViewModels/SearchViewModel.swift
git commit -m "feat: add SearchViewModel with 300ms debounce"
```

---

### Task 6: PosterCard View

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/PosterCard.swift`

- [ ] **Step 1: Create PosterCard.swift**

```swift
import SwiftUI

struct PosterCard: View {
    let item: IMDBItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                case .empty:
                    placeholder
                        .overlay(ProgressView().tint(.white))
                @unknown default:
                    placeholder
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .white.opacity(0.1), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 120, height: 180)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/PosterCard.swift
git commit -m "feat: add PosterCard view with AsyncImage and shadow"
```

---

### Task 7: HeroView

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/HeroView.swift`

- [ ] **Step 1: Create HeroView.swift**

```swift
import SwiftUI

struct HeroView: View {
    let item: IMDBItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 400)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.8), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    if let year = item.year {
                        Text(String(year))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding()
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/HeroView.swift
git commit -m "feat: add HeroView with gradient overlay"
```

---

### Task 8: CategoryRow View

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/CategoryRow.swift`

- [ ] **Step 1: Create CategoryRow.swift**

```swift
import SwiftUI

struct CategoryRow: View {
    let category: ContentCategory
    let onItemTap: (IMDBItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(category.items) { item in
                        PosterCard(item: item) {
                            onItemTap(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/CategoryRow.swift
git commit -m "feat: add CategoryRow with horizontal poster scroll"
```

---

### Task 9: SearchResultRow View

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/SearchResultRow.swift`

- [ ] **Step 1: Create SearchResultRow.swift**

```swift
import SwiftUI

struct SearchResultRow: View {
    let item: IMDBItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
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

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/SearchResultRow.swift
git commit -m "feat: add SearchResultRow view"
```

---

### Task 10: HomeView

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/HomeView.swift`

- [ ] **Step 1: Create HomeView.swift**

```swift
import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onItemTap: (IMDBItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                if let hero = viewModel.heroItem {
                    HeroView(item: hero) {
                        onItemTap(hero)
                    }
                }

                ForEach(viewModel.categories) { category in
                    CategoryRow(category: category, onItemTap: onItemTap)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.black)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/HomeView.swift
git commit -m "feat: add HomeView with hero section and category rows"
```

---

### Task 11: PlayerView (WKWebView + Download Button)

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/PlayerView.swift`

- [ ] **Step 1: Create PlayerView.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/PlayerView.swift
git commit -m "feat: add PlayerView with WKWebView and video URL interception"
```

---

### Task 12: DownloadItem Model

**Files:**
- Create: `PlayIMDB/PlayIMDB/Models/DownloadItem.swift`

- [ ] **Step 1: Create DownloadItem.swift**

```swift
import Foundation

enum DownloadStatus: String, Codable {
    case downloading
    case completed
    case failed
}

struct DownloadItem: Identifiable, Codable {
    let id: String
    let imdbID: String
    let title: String
    let posterURL: String?
    var fileURL: String?
    var progress: Double
    var status: DownloadStatus
    var downloadDate: Date?
    var fileSize: Int64?

    var localFileURL: URL? {
        guard let fileURL else { return nil }
        return URL(fileURLWithPath: fileURL)
    }

    var fileSizeText: String {
        guard let size = fileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var posterImageURL: URL? {
        guard let posterURL else { return nil }
        return URL(string: posterURL)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Models/DownloadItem.swift
git commit -m "feat: add DownloadItem model with status and file tracking"
```

---

### Task 13: DownloadManager Service

**Files:**
- Create: `PlayIMDB/PlayIMDB/Services/DownloadManager.swift`

- [ ] **Step 1: Create DownloadManager.swift**

```swift
import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private var activeTasks: [String: URLSessionDownloadTask] = []
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.playimdb.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let saveKey = "PlayIMDB_Downloads"

    private override init() {
        super.init()
        loadDownloads()
    }

    func startDownload(videoURL: String, imdbID: String, title: String, posterURL: String?) {
        guard !downloads.contains(where: { $0.imdbID == imdbID && $0.status == .downloading }) else { return }

        // Remove any previous failed download for this ID
        downloads.removeAll { $0.imdbID == imdbID && $0.status == .failed }

        guard let url = URL(string: videoURL) else { return }

        let item = DownloadItem(
            id: UUID().uuidString,
            imdbID: imdbID,
            title: title,
            posterURL: posterURL,
            fileURL: nil,
            progress: 0,
            status: .downloading,
            downloadDate: nil,
            fileSize: nil
        )

        downloads.insert(item, at: 0)
        saveDownloads()

        let task = session.downloadTask(with: url)
        task.taskDescription = item.id
        activeTasks[item.id] = task
        task.resume()
    }

    func deleteDownload(_ item: DownloadItem) {
        if let fileURL = item.localFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        downloads.removeAll { $0.id == item.id }
        activeTasks[item.id]?.cancel()
        activeTasks.removeValue(forKey: item.id)
        saveDownloads()
    }

    private func downloadsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveDownloads() {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        downloads = items
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let itemID = downloadTask.taskDescription else { return }

        let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        let fileName = "\(itemID).mp4"
        let destinationURL = destinationDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0

            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .completed
                    self.downloads[index].fileURL = destinationURL.path
                    self.downloads[index].downloadDate = Date()
                    self.downloads[index].fileSize = fileSize
                    self.downloads[index].progress = 1.0
                    self.activeTasks.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        } catch {
            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                    self.downloads[index].status = .failed
                    self.activeTasks.removeValue(forKey: itemID)
                    self.saveDownloads()
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let itemID = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].progress = progress
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let itemID = task.taskDescription else { return }

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[index].status = .failed
                self.activeTasks.removeValue(forKey: itemID)
                self.saveDownloads()
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Services/DownloadManager.swift
git commit -m "feat: add DownloadManager with background download and persistence"
```

---

### Task 14: DownloadsView

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/DownloadsView.swift`

- [ ] **Step 1: Create DownloadsView.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/DownloadsView.swift
git commit -m "feat: add DownloadsView with progress tracking and swipe-to-delete"
```

---

### Task 15: OfflinePlayerView

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/OfflinePlayerView.swift`

- [ ] **Step 1: Create OfflinePlayerView.swift**

```swift
import SwiftUI
import AVKit

struct OfflinePlayerView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Video dosyasi bulunamadi")
                        .foregroundColor(.gray)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            if let fileURL = item.localFileURL,
               FileManager.default.fileExists(atPath: fileURL.path) {
                player = AVPlayer(url: fileURL)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/OfflinePlayerView.swift
git commit -m "feat: add OfflinePlayerView with AVPlayer for local files"
```

---

### Task 16: ContentView (Root with TabView + Search)

**Files:**
- Create: `PlayIMDB/PlayIMDB/Views/ContentView.swift`

- [ ] **Step 1: Create ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var selectedItem: IMDBItem?

    var body: some View {
        NavigationStack {
            Group {
                if searchViewModel.query.isEmpty {
                    HomeView(viewModel: homeViewModel, onItemTap: { item in
                        selectedItem = item
                    })
                } else {
                    ScrollView {
                        if searchViewModel.isSearching {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 40)
                        } else if searchViewModel.results.isEmpty && searchViewModel.query.count >= 2 {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("Sonuc bulunamadi")
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(searchViewModel.results) { item in
                                    SearchResultRow(item: item) {
                                        selectedItem = item
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .background(Color.black)
                }
            }
            .navigationTitle("PlayIMDB")
            .searchable(text: $searchViewModel.query, prompt: "Film veya dizi ara...")
            .onChange(of: searchViewModel.query) { _ in
                searchViewModel.searchTextChanged()
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .task {
                await homeViewModel.loadContent()
            }
            .navigationDestination(item: $selectedItem) { item in
                PlayerView(item: item)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/Views/ContentView.swift
git commit -m "feat: add ContentView with search toggle and navigation to player"
```

---

### Task 17: Wire Up PlayIMDBApp with TabView

**Files:**
- Modify: `PlayIMDB/PlayIMDB/PlayIMDBApp.swift`

- [ ] **Step 1: Update PlayIMDBApp.swift**

Replace the entire contents of `PlayIMDBApp.swift`:

```swift
import SwiftUI

@main
struct PlayIMDBApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Kesfet", systemImage: "film")
                    }

                DownloadsView()
                    .tabItem {
                        Label("Indirilenler", systemImage: "arrow.down.circle")
                    }
            }
            .accentColor(Color("AccentColor"))
            .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PlayIMDB/PlayIMDB/PlayIMDBApp.swift
git commit -m "feat: wire up TabView with ContentView and DownloadsView"
```

---

### Task 18: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/build.yml`

- [ ] **Step 1: Create build.yml**

```yaml
name: Build PlayIMDB

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Build
        run: |
          xcodebuild clean build \
            -project PlayIMDB/PlayIMDB.xcodeproj \
            -scheme PlayIMDB \
            -destination 'generic/platform=iOS' \
            -configuration Release \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Archive
        run: |
          xcodebuild archive \
            -project PlayIMDB/PlayIMDB.xcodeproj \
            -scheme PlayIMDB \
            -destination 'generic/platform=iOS' \
            -archivePath build/PlayIMDB.xcarchive \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Create ExportOptions.plist
        run: |
          cat > build/ExportOptions.plist << 'PLIST'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
              <key>method</key>
              <string>ad-hoc</string>
              <key>thinning</key>
              <string>&lt;none&gt;</string>
              <key>compileBitcode</key>
              <false/>
          </dict>
          </plist>
          PLIST

      - name: Export IPA
        continue-on-error: true
        run: |
          xcodebuild -exportArchive \
            -archivePath build/PlayIMDB.xcarchive \
            -exportPath build/ipa \
            -exportOptionsPlist build/ExportOptions.plist \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload Archive
        uses: actions/upload-artifact@v4
        with:
          name: PlayIMDB-archive
          path: build/PlayIMDB.xcarchive

      - name: Upload IPA
        if: success()
        uses: actions/upload-artifact@v4
        with:
          name: PlayIMDB-ipa
          path: build/ipa/*.ipa
          if-no-files-found: ignore
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: add GitHub Actions build workflow for iOS"
```

---

### Task 19: Generate project.pbxproj

**Files:**
- Create: `PlayIMDB/PlayIMDB.xcodeproj/project.pbxproj`

This is the most complex file. It must reference every source file, asset catalog, and framework. The pbxproj must produce a valid Xcode project that compiles without errors.

- [ ] **Step 1: Create the complete project.pbxproj**

The file must contain:
- **PBXBuildFile** entries for all 16 Swift source files + Assets.xcassets
- **PBXFileReference** entries for all files
- **PBXGroup** entries matching the directory structure (Models, Services, ViewModels, Views, Assets)
- **PBXNativeTarget** named "PlayIMDB" with product type `com.apple.product-type.application`
- **XCBuildConfiguration** for Debug and Release with:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.playimdb.app`
  - `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
  - `SWIFT_VERSION = 5.0`
  - `INFOPLIST_FILE = PlayIMDB/Info.plist`
  - `TARGETED_DEVICE_FAMILY = "1"` (iPhone only)
  - `CODE_SIGN_STYLE = Automatic`
  - `LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks"`
  - `GENERATE_INFOPLIST_FILE = NO`
  - `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
  - `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`
- **PBXFrameworksBuildPhase** (empty — all frameworks are auto-linked)
- **PBXSourcesBuildPhase** with all 16 Swift files
- **PBXResourcesBuildPhase** with Assets.xcassets

Each object needs a unique 24-character hex ID. Use a systematic pattern:
- File refs: `A1000001` through `A1000016` for Swift files, `A1000017` for Assets, `A1000018` for Info.plist
- Build files: `B1000001` through `B1000016` for Swift, `B1000017` for Assets
- Groups: `C1000001` through `C1000008`
- Target: `D1000001`
- Project: `E1000001`
- Build phases: `F1000001` through `F1000003`
- Build configs: `G1000001` through `G1000004`
- Config lists: `H1000001`, `H1000002`
- Product file ref: `A1000019`
- Products group: `C1000009`

Write the complete pbxproj with all entries. Do not use placeholders.

- [ ] **Step 2: Verify project opens (if on macOS)**

```bash
# Only on macOS:
xcodebuild -project PlayIMDB/PlayIMDB.xcodeproj -list
```

Expected: Shows scheme "PlayIMDB" and target "PlayIMDB"

- [ ] **Step 3: Commit**

```bash
git add PlayIMDB/PlayIMDB.xcodeproj/project.pbxproj
git commit -m "feat: add complete Xcode project configuration"
```

---

### Task 20: Final Verification

- [ ] **Step 1: Verify all files exist**

```bash
find PlayIMDB -type f | sort
```

Expected output — all 20+ files listed in the file structure.

- [ ] **Step 2: Verify project builds (if on macOS)**

```bash
xcodebuild clean build \
  -project PlayIMDB/PlayIMDB.xcodeproj \
  -scheme PlayIMDB \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: PlayIMDB iOS app complete — Netflix-style browser with in-app player and downloads"
```
