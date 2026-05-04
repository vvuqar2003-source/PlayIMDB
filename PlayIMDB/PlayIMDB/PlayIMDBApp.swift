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

                WatchHistoryView()
                    .tabItem {
                        Label("Son Izlenenler", systemImage: "clock.arrow.circlepath")
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
