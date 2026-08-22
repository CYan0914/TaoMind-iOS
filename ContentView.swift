import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Binding var dailyVerse: DailyVerse?
    @State private var selectedTab = 0
    @State private var showOnboarding = false

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
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "flame")
            }
            .tag(2)

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label(AppState.tr("Library"), systemImage: "books.vertical")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        .tint(Color(red: 0.4, green: 0.3, blue: 0.18))
        .onAppear {
            // 首启 onboarding（3 屏，仅一次）
            if !appState.hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}
