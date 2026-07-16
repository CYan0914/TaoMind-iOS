import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Binding var dailyVerse: DailyVerse?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SeekWisdomView()
            }
            .tabItem {
                Label("Wisdom", systemImage: "sparkles")
            }
            .tag(0)

            NavigationStack {
                JournalView()
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(Color(red: 0.4, green: 0.3, blue: 0.18))
    }
}
