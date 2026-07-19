import SwiftUI

@main
struct TaoMindApp: App {
    @StateObject private var appState = AppState()
    @State private var dailyVerse: DailyVerse?

    /// Change this to your deployed Railway URL
    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

    init() {
        SubscriptionManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dailyVerse: $dailyVerse)
                .environmentObject(appState)
                .environmentObject(SubscriptionManager.shared)
                .preferredColorScheme(.light)
                .task {
                    await loadDailyVerse()
                }
                .task {
                    // Refresh subscription status on every cold launch
                    await SubscriptionManager.shared.refreshStatus()
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

@MainActor
class AppState: ObservableObject {
    @Published var language: Language = .english
    @Published var dailyVerse: DailyVerse?

    // MARK: - Daily Usage Tracking

    private let defaults = UserDefaults.standard
    private let usageCountKey = "dailySeekCount"
    private let usageDateKey = "dailySeekDate"
    let freeLimit = 3

    /// Whether the user can perform another Seak Wisdom this day
    @MainActor var canSeekWisdom: Bool {
        if SubscriptionManager.shared.isPro { return true }
        resetDailyIfNeeded()
        return defaults.integer(forKey: usageCountKey) < freeLimit
    }

    /// Number of seeks remaining today
    @MainActor var seeksRemainingToday: Int {
        if SubscriptionManager.shared.isPro { return Int.max }
        resetDailyIfNeeded()
        return max(0, freeLimit - defaults.integer(forKey: usageCountKey))
    }

    /// Call after each successful Seek Wisdom
    @MainActor func incrementDailyUsage() {
        guard !SubscriptionManager.shared.isPro else { return }
        resetDailyIfNeeded()
        let count = defaults.integer(forKey: usageCountKey) + 1
        defaults.set(count, forKey: usageCountKey)
    }

    private func resetDailyIfNeeded() {
        let today = dateFormatter.string(from: Date())
        let last = defaults.string(forKey: usageDateKey) ?? ""
        if last != today {
            defaults.set(0, forKey: usageCountKey)
            defaults.set(today, forKey: usageDateKey)
        }
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

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
