import SwiftUI
import RevenueCat

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// 弹墙场景（决定顶部场景条文案；触发点通过 openPaywall(_:) 传入）
    let context: PaywallContext

    init(context: PaywallContext = .generic) {
        self.context = context
    }

    @State private var selectedPackage: Package?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    /// 合并 current offering 与 "lifetime" offering 的所有 package。
    /// Lifetime 买断挂在独立 offering（identifier="lifetime"）上，
    /// 只读 current 的话审核员在 paywall 上看不到 Lifetime 选项（Guideline 2.1(b) 风险）。
    private var mergedPackages: [Package]? {
        guard let offerings = subscriptionManager.offerings else { return nil }
        var pkgs = offerings.current?.availablePackages ?? []
        if let lifetimeOffering = offerings.offering(identifier: "lifetime") {
            let existing = Set(pkgs.map { $0.identifier })
            pkgs += lifetimeOffering.availablePackages.filter { !existing.contains($0.identifier) }
        }
        // 价格锚点：展示顺序不赌 RevenueCat 后台排列——年档（性价比最高）置顶、终身档第二，
        // 其余按周期从长到短，月/周档垫底，让用户第一眼看到的就是最划算的选项。
        pkgs.sort { Self.anchorRank($0.packageType) < Self.anchorRank($1.packageType) }
        return pkgs
    }

    /// 周期越长性价比越高 → 排序越靠前。
    private static func anchorRank(_ type: PackageType) -> Int {
        switch type {
        case .annual: return 0
        case .lifetime: return 1
        case .sixMonth: return 2
        case .threeMonth: return 3
        case .twoMonth: return 4
        case .monthly: return 5
        case .weekly: return 6
        case .daily: return 7
        default: return 8   // .custom / .unknown
        }
    }

    /// 月档价格（Save % 折算基准）；无月档包时为 nil。
    private var monthlyBaseline: Decimal? {
        mergedPackages?.first(where: { $0.packageType == .monthly })?.storeProduct.price
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    VStack(spacing: 12) {
                        Text("☯")
                            .font(.system(size: 56))
                        Text(AppState.tr("Unlock TaoMind Premium"))
                            .font(.custom("Georgia", size: 26, relativeTo: .title))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                        Text(AppState.tr("Full access to ancient wisdom, unlimited"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // MARK: - Context Banner（场景条：为什么此刻弹墙）
                    if context != .generic {
                        HStack(spacing: 10) {
                            Image(systemName: context.icon)
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.18))
                            Text(AppState.tr(context.headlineKey))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.08))
                        .cornerRadius(12)
                    }

                    // MARK: - Features（前 3 条为核心价值 hero，其余为完整清单）
                    VStack(spacing: 14) {
                        HeroFeatureRow(icon: "🧘", text: AppState.tr("pw_master"))
                        HeroFeatureRow(icon: "∞", text: AppState.tr("Unlimited wisdom sessions"))
                        HeroFeatureRow(icon: "🩹", text: AppState.tr("Monthly backfill to heal your streak"))
                        Divider()
                            .padding(.vertical, 2)
                        FeatureRow(icon: "📓", text: AppState.tr("Unlimited journal entries"))
                        FeatureRow(icon: "📚", text: AppState.tr("Full library of the Tao Te Ching & Diamond Sutra"))
                        FeatureRow(icon: "🎋", text: AppState.tr("Streak milestones & share cards"))
                        FeatureRow(icon: "📈", text: AppState.tr("Monthly practice report"))
                        FeatureRow(icon: "🎨", text: AppState.tr("Full response style tuning"))
                        FeatureRow(icon: "📤", text: AppState.tr("Export your journal"))
                    }
                    .padding(.horizontal, 4)

                    // MARK: - Plan Options
                    if subscriptionManager.isLoading && subscriptionManager.offerings == nil {
                        ProgressView()
                            .padding(.vertical, 30)
                    } else if let packages = mergedPackages, !packages.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(packages) { pkg in
                                PlanCard(
                                    package: pkg,
                                    isSelected: selectedPackage?.identifier == pkg.identifier,
                                    monthlyBaseline: monthlyBaseline,
                                    showBestValue: packages.count > 1 && pkg.packageType == .annual,
                                    onTap: { selectedPackage = pkg }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    } else {
                        // Offerings 加载失败/为空：给审核员和用户一个明确的重试入口，而不是空白 paywall
                        VStack(spacing: 12) {
                            Text(AppState.tr("Unable to load purchase options. Please check your connection."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button(AppState.tr("Retry")) {
                                Task { await subscriptionManager.fetchOfferings() }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        }
                        .padding(.vertical, 20)
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
                                    Text(AppState.tr("Start Premium"))
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
                        Button(AppState.tr("Restore Purchases")) {
                            Task {
                                let restored = await subscriptionManager.restore()
                                restoreMessage = restored ? AppState.tr("Purchases restored! 🎉") : AppState.tr("No purchases found to restore.")
                                showRestoreAlert = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        // Terms/Privacy 挂 paywall 底部（Guideline 3.1.2 惯例，提升审核稳健性）
                        HStack(spacing: 14) {
                            Link(AppState.tr("Privacy Policy"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/privacy.html")!)
                            Text("·")
                            Link(AppState.tr("Terms of Service"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/terms.html")!)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)

                        Text(AppState.tr("Subscription auto-renews unless cancelled at least 24h before the end of the period. Manage in App Store settings."))
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
                    Button(AppState.tr("Close")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert(AppState.tr("Restore"), isPresented: $showRestoreAlert) {
                Button(AppState.tr("OK")) {}
            } message: {
                Text(restoreMessage)
            }
            .task {
                // If already Pro, dismiss immediately
                if subscriptionManager.isPro {
                    dismiss()
                    return
                }
                Analytics.paywallView(context: context)
                await subscriptionManager.fetchOfferings()
                // 默认选中年档（价格锚点：把用户的起点放在最划算的选项上）；
                // 年档不存在（RC 后台配置异常）才退回第一顺位。
                if let packages = mergedPackages, !packages.isEmpty {
                    selectedPackage = packages.first(where: { $0.packageType == .annual }) ?? packages.first
                }
            }
            // Auto-dismiss when purchase succeeds
            .onChange(of: subscriptionManager.isPro) { isPro in
                if isPro { dismiss() }
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

// MARK: - Hero Feature Row（前 3 条核心价值，卡片强调样式）

private struct HeroFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.65))
        .cornerRadius(12)
    }
}

// MARK: - PaywallContext icon（场景条用 SF Symbol）

private extension PaywallContext {
    var icon: String {
        switch self {
        case .generic: return "crown"
        case .seekLimitToday: return "sparkles"
        case .journalFull: return "note.text"
        case .libraryLocked: return "books.vertical"
        case .backfill: return "calendar.badge.plus"
        case .monthlyReport: return "chart.line.uptrend.xyaxis"
        case .masterFeedback: return "person.wave.2"
        case .masterFollowup: return "bubble.left.and.text.bubble.right"
        case .journalExport: return "square.and.arrow.up"
        case .styleTuning: return "paintbrush"
        case .seekResult: return "crown"
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let package: Package
    let isSelected: Bool
    /// 月档价格（Save % 折算基准）；无月档包时为 nil。
    let monthlyBaseline: Decimal?
    /// 是否显示 Best Value 徽章（只有年档且列表里有多个选项时才有意义）。
    let showBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))

                        if showBestValue {
                            Text(AppState.tr("pw_best_value"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.72, green: 0.45, blue: 0.20))
                                .clipShape(Capsule())
                        }
                    }

                    if package.packageType == .lifetime {
                        Text(AppState.tr("One-time purchase"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if package.storeProduct.subscriptionPeriod != nil {
                        Text(periodDetail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 价格锚点：长周期档折算月均价 + 相对月档省多少（"$3.33/mo · Save 58%"）
                    if let anchor = priceAnchor {
                        Text(anchor)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.10))
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

    /// 月均折算 + Save % 文案；只对 ≥3 个月的订阅档显示（月/周档无锚点意义，终身档不折算）。
    private var priceAnchor: String? {
        guard let period = package.storeProduct.subscriptionPeriod else { return nil }
        let months: Int
        switch period.unit {
        case .month: months = period.value
        case .year: months = period.value * 12
        default: return nil   // 周/日档不折算
        }
        guard months >= 3 else { return nil }
        let price = NSDecimalNumber(decimal: package.storeProduct.price)
        guard price.doubleValue > 0 else { return nil }
        let perMonth = price.doubleValue / Double(months)
        let equiv = String(format: AppState.tr("pw_monthly_equiv_fmt"), currencySymbol + amountString(perMonth))
        if let baseline = monthlyBaseline {
            let baselineValue = NSDecimalNumber(decimal: baseline).doubleValue
            if baselineValue > 0 && perMonth < baselineValue {
                let save = Int(((1 - perMonth / baselineValue) * 100).rounded())
                if save >= 5 {
                    return equiv + " · " + String(format: AppState.tr("pw_save_fmt"), save)
                }
            }
        }
        return equiv
    }

    /// 从本地化价格串提取货币符号："$39.99"→"$"，"US$39.99"→"US$"，"39,99 €"→"€"。
    private var currencySymbol: String {
        let s = package.localizedPriceString
        let numeric: Set<Character> = ["0","1","2","3","4","5","6","7","8","9",".",","," ","\u{00A0}"]
        let prefix = String(s.prefix { !numeric.contains($0) })
        if !prefix.isEmpty { return prefix }
        return String(s.reversed().prefix { !numeric.contains($0) }.reversed())
    }

    private func amountString(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private var periodDetail: String {
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        switch period.unit {
        case .month:
            return period.value == 1 ? AppState.tr("Monthly") : String(format: AppState.tr("every_n_months_fmt"), period.value)
        case .year:
            return AppState.tr("Annual")
        case .week:
            return AppState.tr("Weekly")
        case .day:
            return AppState.tr("Daily")
        @unknown default:
            return ""
        }
    }
}
