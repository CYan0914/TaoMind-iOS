import SwiftUI

@main
struct TaoMindApp: App {
    @StateObject private var appState = AppState()
    @State private var dailyVerse: DailyVerse?

    /// Change this to your deployed Railway URL
    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

    init() {
        SubscriptionManager.configure()
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dailyVerse: $dailyVerse)
                .environmentObject(appState)
                .environmentObject(SubscriptionManager.shared)
                .preferredColorScheme(.light)
                // Make SwiftUI Text resolve in the selected language (auto-follows system)
                .environment(\.locale, Locale(identifier: appState.language.localeId))
                .task {
                    await loadDailyVerse()
                    // Schedule tomorrow's daily verse notification
                    await NotificationService.shared.scheduleDailyVerse()
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
    /// 当前界面语言（默认跟随系统，可在设置中手动覆盖）
    @Published var language: Language {
        didSet {
            Self.currentLocaleId = language.localeId
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageOverrideKey)
        }
    }
    @Published var dailyVerse: DailyVerse?

    private static let languageOverrideKey = "languageOverride"

    /// 当前语言对应的 locale（供 Bundle 查询与 SwiftUI 环境使用）
    static var currentLocaleId = "en"

    init() {
        // 优先使用用户手动设置的覆盖语言，否则跟随系统语言
        let saved = UserDefaults.standard.string(forKey: Self.languageOverrideKey)
        let system = Locale.preferredLanguages.first ?? "en"
        let detected: Language = saved.flatMap(Language.init(rawValue:)) ?? (system.hasPrefix("zh") ? .chinese : .english)
        self.language = detected
        Self.currentLocaleId = detected.localeId
    }

    /// 根据当前语言翻译字符串（键 = 英文原文，表 = Localizable.strings）
    static func tr(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLocaleId, ofType: "lproj"),
              let langBundle = Bundle(path: path) else { return key }
        return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

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

        /// 用于 SwiftUI 环境 locale 与 Bundle 本地化目录
        var localeId: String {
            switch self {
            case .english: return "en"
            case .chinese: return "zh-Hans"
            }
        }
    }
}
