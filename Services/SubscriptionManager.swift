import Foundation
import RevenueCat

// MARK: - Paywall Context (付费墙场景化：弹墙时刻 → 场景文案)

/// 弹付费墙时的场景上下文。付费墙永远出现在用户刚被限制的那一秒，
/// 场景条负责把"为什么现在弹墙"讲清楚（稀缺性文案，双语 key 见 Localizable.strings）。
enum PaywallContext {
    case generic            // 设置页升级入口等无特定场景
    case seekLimitToday     // 今日 3 次免费求取智慧用完
    case journalFull        // 免费版 20 条日志存满
    case libraryLocked      // 经藏免费试读结束
    case backfill           // 补卡（Pro）
    case monthlyReport      // 修习月报（Pro）
    case masterFeedback     // 本周免费名师指点已用完
    case masterFollowup     // 名师追问（Pro）
    case journalExport      // 导出日志（Pro）
    case styleTuning        // 回复风格调节（Pro）

    var headlineKey: String {
        switch self {
        case .generic: return "pw_ctx_generic"
        case .seekLimitToday: return "pw_ctx_seek_limit"
        case .journalFull: return "pw_ctx_journal_full"
        case .libraryLocked: return "pw_ctx_library_locked"
        case .backfill: return "pw_ctx_backfill"
        case .monthlyReport: return "pw_ctx_monthly_report"
        case .masterFeedback: return "pw_ctx_master_feedback"
        case .masterFollowup: return "pw_ctx_master_followup"
        case .journalExport: return "pw_ctx_journal_export"
        case .styleTuning: return "pw_ctx_style_tuning"
        }
    }
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

    // MARK: - Status

    func refreshStatus() async {
        // Retry up to 3 times — RevenueCat may not be fully initialized yet
        for attempt in 1...3 {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                isPro = customerInfo.entitlements["pro"]?.isActive == true
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
    /// 未登录时跳过（服务端按 session 归户）。
    func syncEntitlementToBackend() async {
        guard AuthService.shared.isSignedIn else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let isPro = customerInfo.entitlements["pro"]?.isActive == true
            let proUntil = customerInfo.entitlements["pro"]?.expirationDate
                .map { ISO8601DateFormatter().string(from: $0) }
            // 上报真实 appUserID：服务端用它向 RevenueCat REST 反查权益，
            // 客户端上报的 isPro 仅作 RevenueCat 不可用时的回退（防伪造）。
            let appUserID = Purchases.shared.appUserID
            _ = try await CheckinService().syncEntitlement(isPro: isPro, proUntil: proUntil, appUserID: appUserID)
            print("[RevenueCat] Entitlement synced: isPro=\(isPro)")
        } catch {
            print("[RevenueCat] Entitlement sync failed: \(error)")
        }
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

    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPro = result.customerInfo.entitlements["pro"]?.isActive == true
            if isPro { showingPaywall = false }
            Task { await syncEntitlementToBackend() }
            return isPro
        } catch {
            print("[RevenueCat] Purchase failed: \(error)")
            return false
        }
    }

    // MARK: - Restore

    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
            Task { await syncEntitlementToBackend() }
            return isPro
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
            isPro = customerInfo.entitlements["pro"]?.isActive == true
            Task { await syncEntitlementToBackend() }
        }
    }
}
