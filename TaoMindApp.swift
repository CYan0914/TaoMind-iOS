import SwiftUI

@main
struct TaoMindApp: App {
    @StateObject private var appState = AppState()
    @State private var dailyVerse: DailyVerse?

    /// Change this to your deployed Railway URL
    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

    var body: some Scene {
        WindowGroup {
            ContentView(dailyVerse: $dailyVerse)
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .task {
                    await loadDailyVerse()
                }
        }
    }

    private func loadDailyVerse() async {
        do {
            let client = APIClient(baseURL: apiBaseURL)
            let verse = try await client.getDailyVerse()
            await MainActor.run {
                appState.dailyVerse = verse
                dailyVerse = verse
            }
        } catch {
            // Use offline fallback
            let fallback = VerseFallback.verseForToday()
            await MainActor.run {
                appState.dailyVerse = DailyVerse(
                    source: fallback.source,
                    chapter: fallback.chapter,
                    verse_text: fallback.text,
                    reflection: fallback.reflection
                )
                dailyVerse = appState.dailyVerse
            }
        }
    }
}

// MARK: - Global App State

class AppState: ObservableObject {
    @Published var language: Language = .english
    @Published var dailyVerse: DailyVerse?
    @Published var isPro: Bool = false

    enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "中文"
            }
        }
    }
}
