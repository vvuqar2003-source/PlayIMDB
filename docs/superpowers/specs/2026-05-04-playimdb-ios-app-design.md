# PlayIMDB iOS App — Design Spec

**Date:** 2026-05-04
**Bundle ID:** com.playimdb.app
**Min iOS:** 16.0
**Dependencies:** None (pure native SwiftUI)

---

## 1. Overview

A Netflix-style iOS app that displays popular movies and TV shows using IMDB's suggestion API. Users can browse curated categories, search for content, and tap any item to watch it in-app via an embedded WKWebView (playimdb.com player with subtitle/episode selection). Users can also download videos for offline viewing.

## 2. Architecture

**Pattern:** MVVM (Model-View-ViewModel)

- **Models:** `IMDBItem` — Codable struct parsed from IMDB suggestion API
- **ViewModels:** `HomeViewModel`, `SearchViewModel` — `@MainActor`, `@Published` properties, async/await data fetching
- **Views:** Pure SwiftUI, dark mode enforced
- **Services:** `IMDBService` — singleton, URLSession-based network layer; `DownloadManager` — video URL interception + background download

## 3. Data Layer

### IMDBService

Single network service class:

```
fetchSuggestions(query: String) async throws -> [IMDBItem]
```

- Endpoint: `https://v3.sg.media-imdb.com/suggestion/x/{query}.json`
- Uses URLSession + JSONDecoder
- Returns array of `IMDBItem`

### IMDBItem Model

```swift
struct IMDBItem: Codable, Identifiable {
    let id: String          // IMDB ID (e.g. "tt0111161")
    let l: String           // Title
    let y: Int?             // Year
    let s: String?          // Actors/description
    let q: String?          // Type (feature, TV series, etc.)
    let i: ImageInfo?       // Poster image
    
    struct ImageInfo: Codable {
        let imageUrl: String
        let width: Int
        let height: Int
    }
}
```

### Curated Content Lists

Home screen categories use hardcoded IMDB ID lists. Each ID is fetched via the suggestion API using the title as query.

| Category | IMDB IDs |
|----------|----------|
| Populer Filmler | tt0111161, tt0068646, tt0071562, tt0468569, tt1375666 |
| Populer Diziler | tt0903747, tt5491994, tt0944947, tt7366338, tt0108778 |
| En Cok Oylanan | tt0050083, tt0167260, tt0110912, tt0060196, tt0120737 |
| Yeni Eklenenler | tt6723592, tt15398776, tt14230458, tt1160419, tt0816692 |

**Fetch strategy:** For each category, fire all 5 requests concurrently via `TaskGroup`, filter results by matching IMDB ID.

## 4. Screens & Navigation

### ContentView (Root)

- `NavigationStack` wrapper
- `.searchable(text:)` modifier for search bar
- When search text is empty: shows `HomeView`
- When search text is non-empty: shows `SearchResultsView`
- `.preferredColorScheme(.dark)` applied at root

### HomeView

- `ScrollView(.vertical)` containing:
  1. **HeroView** — first item from "Populer Filmler", full-width poster with gradient overlay, title, year
  2. **CategoryRow** x4 — each with section title + horizontal scroll of `PosterCard`

### HeroView

- Full-width AsyncImage (aspect ratio ~16:9 crop)
- Bottom gradient: black transparent → black
- Title in bold 28pt, year in 16pt, overlaid on gradient
- Tap opens `PlayerView` (in-app WKWebView)

### CategoryRow

- Section header: bold 20pt title, left-aligned
- `ScrollView(.horizontal, showsIndicators: false)`
- `LazyHStack(spacing: 12)` of `PosterCard`

### PosterCard

- Size: 120w x 180h points
- `AsyncImage` with placeholder (dark gray rectangle)
- `clipShape(RoundedRectangle(cornerRadius: 12))`
- `shadow(color: .white.opacity(0.1), radius: 8)`
- Tap opens `PlayerView` with in-app WKWebView

### SearchResultsView

- `LazyVStack` in a `ScrollView`
- Each row: poster thumbnail (60x90), title (bold), year, type/actors
- 300ms debounce on search text changes before API call

### PlayerView (In-App Player)

- Full-screen `WKWebView` loading `https://www.playimdb.com/title/{imdbID}`
- Navigation bar with back button and download button (arrow-down icon)
- WKWebView configured to allow inline media playback (`allowsInlineMediaPlayback = true`)
- JavaScript injection to intercept video source URLs (`.m3u8`, `.mp4` patterns) via `WKUserContentController`
- Subtitle selection and episode selection handled natively by playimdb.com's UI inside the WebView
- Download button: captures the current video stream URL and passes it to `DownloadManager`

### DownloadsView (Offline Library)

- Accessible via tab bar or navigation — bottom tab bar with 2 tabs: "Kesfet" (Home) and "Indirilenler" (Downloads)
- Lists all downloaded videos with: poster thumbnail, title, file size, download date
- Swipe-to-delete for removing downloads
- Tap to play offline via AVPlayer (native player for local files)
- Shows download progress for active downloads (progress bar)

## 4.5 Download System

### DownloadManager

- `ObservableObject` singleton, `@Published var downloads: [DownloadItem]`
- Uses `URLSession` background download task for video files
- Saves to app's Documents directory: `Documents/Downloads/{imdbID}.mp4`
- `DownloadItem` model: id, title, imdbID, posterURL, fileURL, progress, status (downloading/completed/failed)
- Persists download metadata to UserDefaults or JSON file
- Video URL interception: injects JavaScript into WKWebView to capture video source URLs, sends them back via `WKScriptMessageHandler`

### Interceptor JavaScript

```javascript
// Injected into WKWebView to find video elements
var observer = new MutationObserver(function(mutations) {
    document.querySelectorAll('video source, video').forEach(function(el) {
        var src = el.src || el.getAttribute('src');
        if (src && (src.includes('.mp4') || src.includes('.m3u8'))) {
            window.webkit.messageHandlers.videoURL.postMessage(src);
        }
    });
});
observer.observe(document, { childList: true, subtree: true });
```

## 5. UI / Design

- **Background:** `Color.black` everywhere
- **Color scheme:** `.preferredColorScheme(.dark)` at root
- **Accent color:** Red `#E50914` (defined in AccentColor.colorset)
- **Fonts:** System fonts — `.title.bold()` for headers, `.body` for content
- **Animations:** `.animation(.easeInOut, value:)` on data load transitions
- **Poster placeholders:** Dark gray rounded rectangle while loading

## 6. Project Structure

```
PlayIMDB/
├── PlayIMDB.xcodeproj/
│   └── project.pbxproj
├── PlayIMDB/
│   ├── PlayIMDBApp.swift
│   ├── Models/
│   │   ├── IMDBItem.swift
│   │   └── DownloadItem.swift
│   ├── Services/
│   │   ├── IMDBService.swift
│   │   └── DownloadManager.swift
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift
│   │   └── SearchViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── HomeView.swift
│   │   ├── HeroView.swift
│   │   ├── CategoryRow.swift
│   │   ├── PosterCard.swift
│   │   ├── SearchResultRow.swift
│   │   ├── PlayerView.swift
│   │   ├── DownloadsView.swift
│   │   └── OfflinePlayerView.swift
│   ├── Assets.xcassets/
│   │   ├── AccentColor.colorset/
│   │   │   └── Contents.json
│   │   ├── AppIcon.appiconset/
│   │   │   └── Contents.json
│   │   └── Contents.json
│   └── Info.plist
├── .github/
│   └── workflows/
│       └── build.yml
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-04-playimdb-ios-app-design.md
```

## 7. GitHub Actions Workflow

**File:** `.github/workflows/build.yml`

- **Triggers:** push to `main`, pull_request to `main`
- **Runner:** `macos-latest`
- **Steps:**
  1. `actions/checkout@v4`
  2. Select latest Xcode (`sudo xcode-select -s`)
  3. `xcodebuild archive` — scheme PlayIMDB, destination generic/platform=iOS, archive path `build/PlayIMDB.xcarchive`
  4. `xcodebuild -exportArchive` — export as IPA using ad-hoc export options plist
  5. `actions/upload-artifact@v4` — upload IPA as artifact

**Export Options Plist** (generated in workflow):
- method: ad-hoc
- thinning: none
- compileBitcode: false

## 8. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| External deps | None | AsyncImage + URLSession + WKWebView cover all needs |
| Image loading | AsyncImage | Native, zero config |
| Network | async/await + URLSession | Modern Swift concurrency |
| Project format | .xcodeproj (hand-crafted pbxproj) | No extra tooling needed |
| Navigation | NavigationStack + TabView | iOS 16+ only, modern API |
| Search | .searchable modifier | Native, integrated with NavigationStack |
| Player | WKWebView (playimdb.com) | Full player UI with subtitles/episodes from site |
| Downloads | URLSession background download | Native, supports background transfers |
| Offline playback | AVPlayer | Native player for local .mp4 files |
| Video URL capture | WKScriptMessageHandler | JS injection to intercept video sources |

## 9. Error Handling

- Network failures: show placeholder content, no crash
- Invalid API responses: skip malformed items, display what parses
- No search results: show "Sonuc bulunamadi" message
- Image load failure: AsyncImage shows gray placeholder automatically

## 10. Out of Scope

- User accounts / authentication
- Favorites / watchlist
- Push notifications
- iPad-specific layout
- Localization (UI text is Turkish only)
- HLS stream download (only direct .mp4 URLs are downloadable)
