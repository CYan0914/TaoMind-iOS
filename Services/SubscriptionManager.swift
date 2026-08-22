import Foundation
import RevenueCat

// MARK: - Subscription Manager (RevenueCat wrapper)

@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro = false
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var showingPaywall = false

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
            _ = try await CheckinService().syncEntitlement(isPro: isPro, proUntil: proUntil)
            print("[RevenueCat] Entitlement synced: isPro=\(isPro)")
        } catch {
            print("[RevenueCat] Entitlement sync failed: \(error)")
        }
    }

    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            print("[RevenueCat] Failed to fetch offerings: \(error)")
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
