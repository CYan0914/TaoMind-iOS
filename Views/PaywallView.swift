import SwiftUI
import RevenueCat

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    VStack(spacing: 12) {
                        Text("☯")
                            .font(.system(size: 56))
                        Text("Unlock TaoMind Premium")
                            .font(.custom("Georgia", size: 26, relativeTo: .title))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                        Text("Full access to ancient wisdom, unlimited")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // MARK: - Features
                    VStack(spacing: 14) {
                        FeatureRow(icon: "∞", text: "Unlimited wisdom sessions")
                        FeatureRow(icon: "📓", text: "Unlimited journal entries")
                        FeatureRow(icon: "🎨", text: "Full response style tuning")
                        FeatureRow(icon: "📤", text: "Export your journal")
                    }
                    .padding(.horizontal, 4)

                    // MARK: - Plan Options
                    if subscriptionManager.isLoading && subscriptionManager.offerings == nil {
                        ProgressView()
                            .padding(.vertical, 30)
                    } else if let packages = subscriptionManager.offerings?.current?.availablePackages {
                        VStack(spacing: 12) {
                            ForEach(packages) { pkg in
                                PlanCard(
                                    package: pkg,
                                    isSelected: selectedPackage?.identifier == pkg.identifier,
                                    onTap: { selectedPackage = pkg }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // MARK: - Subscribe Button
                    if selectedPackage != nil {
                        Button(action: purchase) {
                            HStack {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Start Premium")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.17, green: 0.14, blue: 0.09))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(subscriptionManager.isLoading)
                    }

                    // MARK: - Restore + Footer
                    VStack(spacing: 8) {
                        Button("Restore Purchases") {
                            Task {
                                let restored = await subscriptionManager.restore()
                                restoreMessage = restored ? "Purchases restored! 🎉" : "No purchases found to restore."
                                showRestoreAlert = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text("Subscription auto-renews unless cancelled at least 24h before the end of the period. Manage in App Store settings.")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert("Restore", isPresented: $showRestoreAlert) {
                Button("OK") {}
            } message: {
                Text(restoreMessage)
            }
            .task {
                await subscriptionManager.fetchOfferings()
                // Auto-select first (usually yearly — best value)
                if let first = subscriptionManager.offerings?.current?.availablePackages.first {
                    selectedPackage = first
                }
            }
        }
    }

    private func purchase() {
        guard let pkg = selectedPackage else { return }
        Task {
            _ = await subscriptionManager.purchase(pkg)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))

                    if let period = package.storeProduct.subscriptionPeriod {
                        Text(periodDetail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(package.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(red: 0.17, green: 0.14, blue: 0.09) : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color(red: 0.17, green: 0.14, blue: 0.09).opacity(0.05) : Color.white.opacity(0.5))
                    )
            )
        }
    }

    private var periodDetail: String {
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        switch period.unit {
        case .month:
            return period.value == 1 ? "Monthly" : "Every \(period.value) months"
        case .year:
            return "Annual"
        case .week:
            return "Weekly"
        case .day:
            return "Daily"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Package Identifiable conformance

extension Package: @retroactive Identifiable {
    public var id: String { identifier }
}
