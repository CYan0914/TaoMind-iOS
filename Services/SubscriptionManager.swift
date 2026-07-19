import Foundation
import RevenueCat

// MARK: - Subscription Manager (RevenueCat wrapper)

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro = false
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var showingPaywall = false

    private init() {
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
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            print("[RevenueCat] Failed to refresh: \(error)")
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
            isPro = result.customerInfo.entitlements["premium"]?.isActive == true
            if isPro { showingPaywall = false }
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
            isPro = customerInfo.entitlements["premium"]?.isActive == true
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
            isPro = customerInfo.entitlements["premium"]?.isActive == true
        }
    }
}
