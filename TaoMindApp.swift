import SwiftUI
import GoogleSignIn

@main
struct TaoMindApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @State private var dailyVerse: DailyVerse?

    /// Backend API base URL (Tencent Cloud, via Caddy HTTPS)
    private let apiBaseURL = "https://taomindapp.com"

    init() {
        SubscriptionManager.configure()
        // 修 build 39 Google 登录一点闪退：SDK 8.0+ 要求在首次 signIn()
        // 之前显式设置 GIDSignIn.sharedInstance.configuration，否则抛
        // NSInvalidArgumentException 直接闪退。
        Self.configureGoogleSignIn()
        // 修 build 48 Library hub 闪一下只显示 2 张卡的 bug：
        // JingjiangService.load() 同步从 bundle 读 jingjiang.json（约 1.5MB），
        // 在 app 启动时预热可以让 Library tab 首次打开时 hub 直接 3 张卡全显。
        JingjiangService.shared.load()
        // 通知权限改在首启 onboarding 第 3 屏请求（价值预告之后，转化更好）
    }

    /// 显式从 bundle 的 GoogleService-Info.plist 读 CLIENT_ID 并配置 GIDSignIn。
    /// 显式比 GIDSignIn.sharedInstance.start() 更可靠：不依赖 SDK 的 plist 解析路径，
    /// 也不阻塞启动（同步设置好再走 main runloop）。
    private static func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let clientID = dict["CLIENT_ID"] as? String else {
            print("[Auth] GoogleService-Info.plist not found in bundle — Google Sign-In disabled")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("[Auth] GIDSignIn configured with clientID \(clientID.prefix(20))…")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dailyVerse: $dailyVerse)
                .environmentObject(appState)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(AuthService.shared)
                .preferredColorScheme(.light)
                // Make SwiftUI Text resolve in the selected language (auto-follows system)
                .environment(\.locale, Locale(identifier: appState.language.localeId))
                .task {
                    await loadDailyVerse()
                    // Schedule tomorrow's daily verse notification
                    await NotificationService.shared.scheduleDailyVerse()
                    // Schedule the habit loop (断签预警 / 召回 / 里程碑)
                    await NotificationService.shared.scheduleHabitNotifications()
                }
                .task {
                    // Refresh subscription status on every cold launch
                    await SubscriptionManager.shared.refreshStatus()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        // 回到前台时重排习惯通知（打卡状态可能已变）
                        Task { await NotificationService.shared.scheduleHabitNotifications() }
                        // 登录后重试从 deep link 暂存的邀请码
                        if AuthService.shared.isSignedIn {
                            Task { await ReferralService.shared.tryPendingRedeem() }
                        }
                    }
                }
                .onOpenURL { url in
                    ReferralService.shared.handleDeepLink(url)
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

    /// 是否已看过首启 onboarding（3 屏：价值预告 → 生活困惑 → 通知请求）
    @Published var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.onboardingSeenKey) }
    }

    /// 首启 onboarding 选择的生活困惑方向（ScenarioType.apiValue，如 "career"）
    /// 随当日打卡传给后端，决定第一天名师指点的回应方向。
    @Published var userIntent: String? {
        didSet { UserDefaults.standard.set(userIntent, forKey: Self.userIntentKey) }
    }

    private static let languageOverrideKey = "languageOverride"
    private static let onboardingSeenKey = "hasSeenOnboarding"
    private static let userIntentKey = "userIntent"

    /// 当前语言对应的 locale（供 Bundle 查询与 SwiftUI 环境使用）
    static var currentLocaleId = "en"

    init() {
        // 优先使用用户手动设置的覆盖语言，否则跟随系统语言
        let saved = UserDefaults.standard.string(forKey: Self.languageOverrideKey)
        let system = Locale.preferredLanguages.first ?? "en"
        let detected: Language = saved.flatMap(Language.init(rawValue:)) ?? (system.hasPrefix("zh") ? .chinese : .english)
        self.language = detected
        Self.currentLocaleId = detected.localeId
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingSeenKey)
        self.userIntent = UserDefaults.standard.string(forKey: Self.userIntentKey)
    }

    /// 根据当前语言翻译字符串（键 = 英文原文，表 = Localizable.strings）
    static func tr(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLocaleId, ofType: "lproj"),
              let langBundle = Bundle(path: path) else { return key }
        return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    /// 翻译带格式化参数的字符串，如 tr("total_checkins_fmt", 5)
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), arguments: args)
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
