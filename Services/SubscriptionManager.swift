import Foundation
import RevenueCat

// MARK: - Paywall Feature (付费墙功能清单，按场景筛选)

/// 付费墙上的功能条目。场景决定展示哪三条 —— 全量罗列 9 条对第一次看墙的人是信息过载。
enum PaywallFeature: CaseIterable {
    case master
    case unlimitedSeek
    case backfill
    case journal
    case library
    case milestones
    case report
    case styleTuning
    case journalExport

    var icon: String {
        switch self {
        case .master: return "person.wave.2"
        case .unlimitedSeek: return "infinity"
        case .backfill: return "calendar.badge.plus"
        case .journal: return "book"
        case .library: return "books.vertical"
        case .milestones: return "leaf"
        case .report: return "chart.line.uptrend.xyaxis"
        case .styleTuning: return "paintbrush"
        case .journalExport: return "square.and.arrow.up"
        }
    }

    var titleKey: String {
        switch self {
        case .master: return "pw_master"
        case .unlimitedSeek: return "Unlimited wisdom sessions"
        case .backfill: return "Monthly backfill to heal your streak"
        case .journal: return "Unlimited journal entries"
        case .library: return "Full library of the Tao Te Ching & Diamond Sutra"
        case .milestones: return "Streak milestones & share cards"
        case .report: return "Monthly practice report"
        case .styleTuning: return "Full response style tuning"
        case .journalExport: return "Export your journal"
        }
    }
}

// MARK: - Paywall Context (付费墙场景化：弹墙时刻 → 场景文案)

/// 弹付费墙时的场景上下文。付费墙永远出现在用户刚被限制的那一秒，
/// 场景条负责把"为什么现在弹墙"讲清楚（稀缺性文案，双语 key 见 Localizable.strings）。
enum PaywallContext {
    case generic            // 设置页升级入口等无特定场景
    case seekLimitToday     // 今日 3 次免费求取智慧用完
    case journalFull        // 免费版 20 条日志存满
    case libraryLocked      // 经藏免费试读结束
    case jingjiangLocked    // 道德经·精讲试读结束（1 章免费，余 Pro）
    case backfill           // 补卡（Pro）
    case monthlyReport      // 修习月报（Pro）
    case masterFeedback     // 本周免费名师指点已用完
    case masterFollowup     // 名师追问（Pro）
    case journalExport      // 导出日志（Pro）
    case styleTuning        // 回复风格调节（Pro）
    case seekResult         // 求取智慧结果页（心流转化位）
    case personalizedDailyVerse  // build 50: 每日情绪定制经文 Day 4+ 升级 banner

    var headlineKey: String {
        switch self {
        case .generic: return "pw_ctx_generic"
        case .seekLimitToday: return "pw_ctx_seek_limit"
        case .journalFull: return "pw_ctx_journal_full"
        case .libraryLocked: return "pw_ctx_library_locked"
        case .jingjiangLocked: return "pw_ctx_jingjiang_locked"
        case .backfill: return "pw_ctx_backfill"
        case .monthlyReport: return "pw_ctx_monthly_report"
        case .masterFeedback: return "pw_ctx_master_feedback"
        case .masterFollowup: return "pw_ctx_master_followup"
        case .journalExport: return "pw_ctx_journal_export"
        case .styleTuning: return "pw_ctx_style_tuning"
        case .seekResult: return "pw_ctx_seek_result"
        case .personalizedDailyVerse: return "pw_ctx_personalized_daily_verse"
        }
    }

    /// 该场景下最相关的三条功能。nil = 通用场景，展示完整九条清单。
    var featuredFeatures: [PaywallFeature]? {
        switch self {
        case .generic:
            return nil
        case .seekLimitToday, .seekResult, .personalizedDailyVerse:
            return [.unlimitedSeek, .master, .library]
        case .libraryLocked, .jingjiangLocked:
            return [.library, .unlimitedSeek, .master]
        case .journalFull:
            return [.journal, .journalExport, .master]
        case .backfill:
            return [.backfill, .milestones, .library]
        case .monthlyReport:
            return [.report, .milestones, .backfill]
        case .masterFeedback, .masterFollowup:
            return [.master, .unlimitedSeek, .styleTuning]
        case .journalExport:
            return [.journalExport, .journal, .master]
        case .styleTuning:
            return [.styleTuning, .master, .unlimitedSeek]
        }
    }
}

// MARK: - Purchase Outcome

/// 购买结果。取消与失败必须分开：用户主动取消不该弹错误提示，
/// 但失败（网络/支付/Store 问题）必须给出可执行文案 —— 原来 catch 只打日志，
/// 用户点了「Start Premium」没反应，会以为 App 卡死。
enum PurchaseOutcome {
    case success
    case cancelled
    case failed
}

// MARK: - Subscription Manager (RevenueCat wrapper)

@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro = false
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var showingPaywall = false
    @Published var paywallContext: PaywallContext = .generic

    /// 弹付费墙的唯一入口：先记场景再弹墙，PaywallView 据此展示场景条。
    func openPaywall(_ context: PaywallContext = .generic) {
        paywallContext = context
        showingPaywall = true
    }

    override private init() {
        super.init()
        // 读回本地体验卡：不读的话，进程重启到 refreshStatus 返回之间
        // 体验期内的用户会看到 Pro 权益闪断成付费墙。
        if let saved = UserDefaults.standard.object(forKey: Self.trialUntilKey) as? Date {
            trialUntil = saved
            if saved > Date() { isPro = true }
        }
        Purchases.shared.delegate = self
        Task { await refreshStatus() }
    }

    // MARK: - Configuration (called at app launch)

    static func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_FMDsmQuAewPKirJginmwmALxQiS")
                .with(appUserID: nil) // anonymous
        )
    }

    // MARK: - Trial（连续打卡奖励的 7 天体验卡）

    private static let trialUntilKey = "trial.pro.until"

    /// 本地记录的体验卡到期时间。
    /// 服务端发放时只写 pro_until，而客户端 isPro 读的是 RevenueCat entitlement ——
    /// 两者不通，所以必须把到期时间回传并在本地也记一份，否则用户拿到了卡界面照样全锁着。
    @Published var trialUntil: Date?

    var isTrialActive: Bool {
        guard let until = trialUntil else { return false }
        return until > Date()
    }

    /// RevenueCat 权益 ∨ 体验卡。**所有 isPro 赋值都必须走这里** ——
    /// 直接赋值会让任何一次 refreshStatus / delegate 回调把体验卡解锁的 Pro 抹掉。
    private func setPro(rcActive: Bool) {
        isPro = rcActive || isTrialActive
    }

    /// 体验卡是否已领过（终身一次）。领过后打卡进度条要撤掉 ——
    /// 否则等于承诺一个永远不会再兑现的奖励。
    static let trialClaimedKey = "trial.claimed"

    /// 权益未能上报后端时的 pending 标记（未登录 / 网络失败）。
    /// 登录成功后 `flushPendingEntitlementSync()` 会补传并清掉它。
    static let pendingSyncKey = "entitlement.sync.pending"
    var hasClaimedTrial: Bool { UserDefaults.standard.bool(forKey: Self.trialClaimedKey) }

    /// 应用后端发放的 7 天体验卡（连续打卡 7 天的奖励）：落盘 + 立即解锁 UI。
    /// 刻意不调 syncEntitlementToBackend —— 后端刚在 /checkin 里写好 pro_until，
    /// 而这里能上报的只有 RevenueCat 的 false，多此一举还平添被覆盖的机会。
    func applyTrial(until date: Date) {
        trialUntil = date
        UserDefaults.standard.set(date, forKey: Self.trialUntilKey)
        UserDefaults.standard.set(true, forKey: Self.trialClaimedKey)
        isPro = true
    }

    // MARK: - Status

    func refreshStatus() async {
        // Retry up to 3 times — RevenueCat may not be fully initialized yet
        for attempt in 1...3 {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                setPro(rcActive: customerInfo.entitlements["pro"]?.isActive == true)
                if isPro { print("[RevenueCat] Premium active ✅") }
                Task { await syncEntitlementToBackend() }
                return
            } catch {
                print("[RevenueCat] Refresh attempt \(attempt)/3 failed: \(error)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * Double(attempt)))
                }
            }
        }
        print("[RevenueCat] All refresh attempts exhausted — isPro stays false")
    }

    // MARK: - Entitlement sync to backend (W1 服务端权益校验骨架)

    /// 把 RevenueCat 权益状态上报给服务端，使 require_pro 端点可用。
    ///
    /// 服务端按 session 归户，所以没登录时**上报不了** —— 但绝不能静默吞掉：
    /// 永久会员在未登录状态下买到 Pro（或登录态过期、换设备未登录），
    /// 凭证不上报的话后端 `is_user_pro()` 一直是 false，用户按免费额度被限流，
    /// 当天第一次提问就撞 429「免费次数已用完」。所以这里落一个 pending 标记，
    /// 等登录成功后由 `flushPendingEntitlementSync()` 立刻补传。
    func syncEntitlementToBackend() async {
        guard AuthService.shared.isSignedIn else {
            UserDefaults.standard.set(true, forKey: Self.pendingSyncKey)
            print("[RevenueCat] Not signed in — entitlement sync deferred (pending flag set)")
            return
        }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let isPro = customerInfo.entitlements["pro"]?.isActive == true
            let proUntil = customerInfo.entitlements["pro"]?.expirationDate
                .map { ISO8601DateFormatter().string(from: $0) }
            // 上报真实 appUserID：服务端用它向 RevenueCat REST 反查权益，
            // 客户端上报的 isPro 仅作 RevenueCat 不可用时的回退（防伪造）。
            let appUserID = Purchases.shared.appUserID
            _ = try await CheckinService().syncEntitlement(isPro: isPro, proUntil: proUntil, appUserID: appUserID)
            UserDefaults.standard.removeObject(forKey: Self.pendingSyncKey)
            print("[RevenueCat] Entitlement synced: isPro=\(isPro)")
        } catch {
            UserDefaults.standard.set(true, forKey: Self.pendingSyncKey)
            print("[RevenueCat] Entitlement sync failed (pending flag set): \(error)")
        }
    }

    /// 登录成功后立刻补传一次被推迟的权益（幂等：无 pending 也会跑一次，
    /// 因为登录后服务端本来就该知道当前权益）。
    func flushPendingEntitlementSync() async {
        guard AuthService.shared.isSignedIn else { return }
        await syncEntitlementToBackend()
    }

    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        // Retry up to 3 times — a failed load leaves the paywall with no purchase
        // options at all (App Store review Guideline 2.1(b) risk).
        for attempt in 1...3 {
            do {
                offerings = try await Purchases.shared.offerings()
                if offerings != nil { return }
                print("[RevenueCat] Offerings empty on attempt \(attempt)/3")
            } catch {
                print("[RevenueCat] Offerings attempt \(attempt)/3 failed: \(error)")
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * Double(attempt)))
            }
        }
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }
        Analytics.purchaseStart(packageID: package.identifier)
        do {
            let result = try await Purchases.shared.purchase(package: package)
            let rcActive = result.customerInfo.entitlements["pro"]?.isActive == true
            setPro(rcActive: rcActive)
            if rcActive {
                Analytics.purchaseSuccess(packageID: package.identifier)
                showingPaywall = false
            }
            Task { await syncEntitlementToBackend() }
            // 返回真实购买结果，不是 isPro —— 体验期内 isPro 恒为 true，
            // 拿它当返回值会让「购买失败」被误报成成功。
            return rcActive ? .success : .failed
        } catch {
            Analytics.purchaseFail(packageID: package.identifier)
            print("[RevenueCat] Purchase failed: \(error)")
            // RevenueCat 把 ErrorCode 直接作为 Error 抛出；用户取消不是故障，
            // 静默返回即可，否则每次关掉系统支付面板都弹一次错误。
            let nsError = error as NSError
            let rcCode = (error as? RevenueCat.ErrorCode)
                ?? RevenueCat.ErrorCode(rawValue: nsError.code)
            return rcCode == .purchaseCancelledError ? .cancelled : .failed
        }
    }

    // MARK: - Restore

    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let rcActive = customerInfo.entitlements["pro"]?.isActive == true
            setPro(rcActive: rcActive)
            // 同上：体验期内 isPro 恒为 true，用它判断会把「没有可恢复的购买」
            // 误报成"恢复成功"。这里只看 RevenueCat 的真实结果。
            Analytics.track(rcActive ? "restore_success" : "restore_empty")
            Task { await syncEntitlementToBackend() }
            return rcActive
        } catch {
            print("[RevenueCat] Restore failed: \(error)")
            return false
        }
    }
}

// MARK: - RevenueCat Delegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            setPro(rcActive: customerInfo.entitlements["pro"]?.isActive == true)
            Task { await syncEntitlementToBackend() }
        }
    }
}
