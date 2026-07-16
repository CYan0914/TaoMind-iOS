import SwiftUI

// MARK: - App Entry Point Loader

/// On launch, fetch daily verse and cache it.
/// This runs as a task modifer on ContentView.
struct DailyVerseLoader: ViewModifier {
    @EnvironmentObject var appState: AppState
    @State private var loaded = false

    func body(content: Content) -> some View {
        content
            .task {
                guard !loaded else { return }
                loaded = true
                // Fetch daily verse on launch
                let client = APIClient()
                if let verse = try? await client.getDailyVerse() {
                    await MainActor.run {
                        appState.dailyVerse = verse
                    }
                }
            }
    }
}

extension View {
    func loadDailyVerseOnLaunch() -> some View {
        modifier(DailyVerseLoader())
    }
}
