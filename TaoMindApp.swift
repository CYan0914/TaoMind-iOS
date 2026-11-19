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
                .onChange(of: appState.language) { _ in
                    // 切中英文 → 换文案的活全在渲染层：`DailyVerse.localized()` 按
                    // 当前语言挑字段，base verse 自带中英双列，个性化 verse 的中英
                    // 两槽也都躺在同一个日期实体里。所以这里**只补一条可能为空的槽**。
                    //
                    // 1.8.0 的写法是重跑整个 `loadDailyVerse()`，而它无条件先把 base
                    // verse 写进 `appState.dailyVerse`（base 的章由后端按日期定，与
                    // LLM 选的那章本就无关）；个性化一旦失败就永久停在 base —— 这是
                    // 「中文金刚经 28 章、切英文变道德经」的必经中间态。
                    //
                    // 只调 loadPersonalizedVerse 还有一个好处：未登录 / 非 Pro 时它
                    // 第一行就 return，`dailyVerse` 分毫不动。原来那条路径会把
                    // `dailyVerse` 冲成 base，正是「切语言经文消失」的一条通路。
                    Task { await loadPersonalizedVerse(recentReflections: nil) }
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
                // base verse 双语齐全，存一份供切语言补槽失败时回退
                appState.baseVerse = verse
                appState.dailyVerse = verse
                dailyVerse = verse
            }
        } catch {
            // 离线兜底：按当前界面语言组装（中英两槽都填）。
            // 老写法把英文 fallback 塞进 `verse_text`（中文槽），中文界面
            // 断网时必然显示英文经文。
            await MainActor.run {
                let fallback = VerseFallback.dailyVerse(isEnglish: appState.language == .english)
                appState.baseVerse = fallback
                appState.dailyVerse = fallback
                dailyVerse = fallback
            }
        }
        // build 50: Step B — 若已登录且 (Pro 或 Day 1-3 free trial),
        // 后台并发拉个性化 verse,成功则覆盖 dailyVerse + 写 personalizedVerse。
        // 失败静默降级,留 fixed verse。
        await loadPersonalizedVerse(recentReflections: nil)
    }

    /// build 50: 个性化 verse 拉取。1.8.1 起是**幂等**的:目标语言槽已有内容
    /// 就是一次纯本地读,不发请求 —— 切语言走的就是这条路。
    /// - 无登录/不在 trial/Pro  → skip(`appState.dailyVerse` 分毫不动)
    /// - 目标语言槽已有 → 本地返回
    /// - 目标语言槽为空 → 补一次 LLM,用另一槽锁死章节
    /// - 失败 → personalizedVerseFailedToday = true(PracticeView 据此显 upgrade banner)
    private func loadPersonalizedVerse(recentReflections: [String]?) async {
        let svc = PersonalizedDailyVerseService()
        guard svc.isEligible() else {
            // 之前是裸 return。但个性化 verse 是按语言分槽的：英文模式生成的
            // 那份只有 `_en` 三列，用户切中文后若这条路径直接返回，卡片会一直
            // 停在英文形态。改成「目标语言没内容就退回 base verse」。
            await MainActor.run {
                appState.restoreBaseVerseIfNeeded()
                dailyVerse = appState.dailyVerse
            }
            return
        }
        // 跨日清 mood cache
        svc.clearStaleMoodIfNewDay()
        // 重新从 UserDefaults 读(可能在 PracticeView 里刚被改)
        let mood = svc.todaysMood() ?? appState.todaysMood
        let language = appState.language.rawValue
        do {
            let personalized = try await svc.fetchTodaysPersonalizedVerse(
                mood: mood,
                recentReflections: recentReflections ?? [],
                userIntent: appState.userIntent,
                language: language
            )
            await MainActor.run {
                appState.dailyVerse = personalized
                dailyVerse = personalized
                appState.personalizedVerse = personalized
                appState.personalizedVerseFailedToday = false
            }
        } catch {
            await MainActor.run {
                appState.personalizedVerseFailedToday = true
                // 补槽失败（未登录 / LLM 超时 / 额度限流）→ 目标语言没有内容时
                // 退回 base verse，否则中文界面会一直显示英文槽的内容。
                appState.restoreBaseVerseIfNeeded()
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
            Self.uiLocaleId = Self.resolveUILocale(
                language, system: Locale.preferredLanguages.first ?? "en")
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageOverrideKey)
        }
    }
    @Published var dailyVerse: DailyVerse?

    /// 后端 /daily-verse 返回的固定经文（中英两槽齐全）。
    ///
    /// 个性化 verse 按语言分槽：英文模式生成的那份只有 `_en` 三列。用户从英文
    /// 切中文时若补中文槽失败（未登录、LLM 超时、额度限流），`dailyVerse` 会
    /// 一直停在英文形态，`localized()` 只能回落到英文槽 —— 中文界面显示英文
    /// 经文。回退到这份 base verse 才是对的。
    @Published var baseVerse: DailyVerse?

    /// 当前显示的 verse 在**当前界面语言**下是否真的有内容，没有就退回 base verse。
    /// 已有目标语言内容就不动（个性化通常比固定经文更贴切）。
    ///
    /// 中文判定要求「出现汉字」而不是「非空」：老缓存里存在中文槽装着英文的
    /// 形态，非空判断会让它继续显示英文。
    @discardableResult
    func restoreBaseVerseIfNeeded() -> Bool {
        let zhText = dailyVerse?.verse_text ?? ""
        let hasTargetLanguageContent: Bool
        switch language {
        case .chinese:
            hasTargetLanguageContent = zhText.unicodeScalars
                .contains { (0x4E00...0x9FFF).contains($0.value) }
        case .english:
            hasTargetLanguageContent = !((dailyVerse?.verse_text_en ?? "").isEmpty)
        }
        guard !hasTargetLanguageContent, let base = baseVerse else { return false }
        dailyVerse = base
        personalizedVerse = nil
        return true
    }

    /// 是否已看过首启 onboarding（3 屏：价值预告 → 生活困惑 → 通知请求）
    @Published var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.onboardingSeenKey) }
    }

    /// 首启 onboarding 选择的生活困惑方向（ScenarioType.apiValue，如 "career"）
    /// 随当日打卡传给后端，决定第一天名师指点的回应方向。
    @Published var userIntent: String? {
        didSet { UserDefaults.standard.set(userIntent, forKey: Self.userIntentKey) }
    }

    // MARK: - build 50: Personalized Daily Verse (情绪化每日经文)

    /// 当日 mood（无日期后缀；跨日由 PersonalizedDailyVerseService.clearStaleMoodIfNewDay 清空）
    @Published var todaysMood: Mood? {
        didSet { UserDefaults.standard.set(todaysMood?.rawValue, forKey: "todaysMood") }
    }

    /// 首装日期（Day 1 锚，存一次永不变；用作 3 天免费 trial 判定）
    @Published var installDate: Date {
        didSet { UserDefaults.standard.set(installDate, forKey: "installDate") }
    }

    /// 当日个性化 verse（仅内存，不持久化；DailyVerseCard 据此显示「为你而选」eyebrow）
    @Published var personalizedVerse: DailyVerse?

    /// 当日 LLM 失败标记：避免无意义重试；同时驱动 PracticeView 的 upgrade banner 显隐
    @Published var personalizedVerseFailedToday: Bool = false

    // MARK: - 跨视图导航（增值型邀请：seek 保存到日志 → 引导进经藏）

    /// 底部 tab 选中项。提到 AppState 是为了让 SeekWisdomView 保存日志后能跳到经藏 tab。
    /// 值语义与原来的 @State 完全一致（都是值变才重绘），不增加重绘次数。
    @Published var selectedTab: Int = 0

    /// 经藏邀请弹窗显隐。sheet 统一挂 ContentView 顶层，理由见 ContentView 注释。
    @Published var showingLibraryInvite = false

    /// 经藏 tab 在 ContentView TabView 中的 tag
    static let libraryTabTag = 1

    private static let languageOverrideKey = "languageOverride"
    private static let onboardingSeenKey = "hasSeenOnboarding"
    private static let userIntentKey = "userIntent"

    /// 当前语言对应的 locale（供 Bundle 查询与 SwiftUI 环境使用）
    static var currentLocaleId = "en"

    /// UI 文案实际走哪个 `.lproj`。
    ///
    /// `currentLocaleId` 只有 `zh-Hans` / `en` 两个值，全项目十来处用 `== "zh-Hans"`
    /// 判断该取中文槽还是英文槽，动它会连带改内容选择。所以繁简细分只落在这里：
    /// 港台/澳门用户系统是 zh-Hant，仍按中文内容走，但界面换成繁体文案。
    static var uiLocaleId = "en"

    /// 中文再按系统地区分繁简。认不出的中文一律回简体（大陆/新马）。
    static func resolveUILocale(_ language: Language, system: String) -> String {
        guard language == .chinese else { return "en" }
        let s = system.lowercased()
        if s.hasPrefix("zh-hant") || s.hasPrefix("zh-tw")
            || s.hasPrefix("zh-hk") || s.hasPrefix("zh-mo") {
            return "zh-Hant"
        }
        return "zh-Hans"
    }

    init() {
        // 优先使用用户手动设置的覆盖语言，否则跟随系统语言
        let saved = UserDefaults.standard.string(forKey: Self.languageOverrideKey)
        let system = Locale.preferredLanguages.first ?? "en"
        let detected: Language = saved.flatMap(Language.init(rawValue:)) ?? (system.hasPrefix("zh") ? .chinese : .english)
        self.language = detected
        Self.currentLocaleId = detected.localeId
        Self.uiLocaleId = Self.resolveUILocale(detected, system: system)
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingSeenKey)
        self.userIntent = UserDefaults.standard.string(forKey: Self.userIntentKey)
        // 首装日期锚（首次启动 seed 当下；后续读取已有值）
        if let existing = UserDefaults.standard.object(forKey: "installDate") as? Date {
            self.installDate = existing
        } else {
            let now = Date()
            self.installDate = now
            UserDefaults.standard.set(now, forKey: "installDate")
        }
        // 当日 mood（跨日清空）
        self.todaysMood = UserDefaults.standard.string(forKey: "todaysMood").flatMap(Mood.init(rawValue:))
    }

    /// 根据当前语言翻译字符串（键 = 英文原文，表 = Localizable.strings）
    static func tr(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: uiLocaleId, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        // 繁体表缺失时退回简体，别直接吐英文 key
        if uiLocaleId == "zh-Hant",
           let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return key
    }

    /// 翻译带格式化参数的字符串，如 tr("total_checkins_fmt", 5)
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), arguments: args)
    }

    // MARK: - Daily Usage Tracking

    private let defaults = UserDefaults.standard
    private let usageCountKey = "dailySeekCount"
    private let usageDateKey = "dailySeekDate"
    private let totalSeekCountKey = "totalSeekCount"

    /// 免费额度：每天 3 次。
    /// 分档结构（首日 / 次日起）保留备用 —— 2026-10-12 起两档取同值，
    /// 将来若要恢复「首日多、之后少」，只改下面两个数值即可。
    /// 首日按 installDate 的本地日历日判定 —— 装机当天就该算首日，与账号注册时间无关。
    private let firstDayFreeLimit = 3
    private let subsequentFreeLimit = 3

    private var isFirstDay: Bool {
        Calendar.current.isDate(installDate, inSameDayAs: Date())
    }

    @MainActor private var currentFreeLimit: Int {
        isFirstDay ? firstDayFreeLimit : subsequentFreeLimit
    }

    /// 终身累计求取次数（跨日不重置）：评分触发点「第 2 次求取智慧」据此判定
    var totalSeekCount: Int { defaults.integer(forKey: totalSeekCountKey) }

    /// Whether the user can perform another Seak Wisdom this day
    @MainActor var canSeekWisdom: Bool {
        if SubscriptionManager.shared.isPro { return true }
        resetDailyIfNeeded()
        return defaults.integer(forKey: usageCountKey) < currentFreeLimit
    }

    /// Number of seeks remaining today
    @MainActor var seeksRemainingToday: Int {
        if SubscriptionManager.shared.isPro { return Int.max }
        resetDailyIfNeeded()
        return max(0, currentFreeLimit - defaults.integer(forKey: usageCountKey))
    }

    /// Call after each successful Seek Wisdom
    @MainActor func incrementDailyUsage() {
        // 累计计数对所有用户生效（含 Pro）—— 评分触发点不区分付费状态
        defaults.set(defaults.integer(forKey: totalSeekCountKey) + 1, forKey: totalSeekCountKey)
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
