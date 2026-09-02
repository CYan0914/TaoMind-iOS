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

    /// Lifetime 居首（用户原话：lifetime 排在最上面）→ 其余按周期从长到短。
    private static func anchorRank(_ type: PackageType) -> Int {
        switch type {
        case .lifetime: return 0
        case .annual: return 1
        case .sixMonth: return 2
        case .threeMonth: return 3
        case .twoMonth: return 4
        case .monthly: return 5
        case .weekly: return 6
        default: return 7   // .custom / .unknown（PackageType 无 daily）
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
                    VStack(spacing: 10) {
                        Text(AppState.tr("pw_eyebrow"))
                            .eyebrowStyle(DS.nightGold)
                        Text(AppState.tr("Unlock TaoMind Premium"))
                            .font(DS.display(27, weight: .black, relativeTo: .title2))
                            .foregroundColor(DS.nightText)
                        Text(AppState.tr("Full access to ancient wisdom, unlimited"))
                            .font(.subheadline)
                            .foregroundColor(DS.nightSoft)
                    }
                    .padding(.top, 20)

                    // MARK: - Context Banner（场景条：为什么此刻弹墙）
                    if context != .generic {
                        HStack(spacing: 10) {
                            Image(systemName: context.icon)
                                .font(.subheadline)
                                .foregroundColor(DS.nightGold)
                            Text(AppState.tr(context.headlineKey))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DS.nightText)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.small)
                                .fill(DS.nightGold.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.small)
                                .stroke(DS.nightGold.opacity(0.30), lineWidth: 1)
                        )
                    }

                    // MARK: - Features（前 3 条为核心价值 hero，其余为完整清单）
                    VStack(spacing: 14) {
                        HeroFeatureRow(icon: "person.wave.2", text: AppState.tr("pw_master"))
                        HeroFeatureRow(icon: "infinity", text: AppState.tr("Unlimited wisdom sessions"))
                        HeroFeatureRow(icon: "calendar.badge.plus", text: AppState.tr("Monthly backfill to heal your streak"))
                        Divider()
                            .overlay(DS.nightText.opacity(0.15))
                            .padding(.vertical, 2)
                        FeatureRow(icon: "book", text: AppState.tr("Unlimited journal entries"))
                        FeatureRow(icon: "books.vertical", text: AppState.tr("Full library of the Tao Te Ching & Diamond Sutra"))
                        FeatureRow(icon: "leaf", text: AppState.tr("Streak milestones & share cards"))
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: AppState.tr("Monthly practice report"))
                        FeatureRow(icon: "paintbrush", text: AppState.tr("Full response style tuning"))
                        FeatureRow(icon: "square.and.arrow.up", text: AppState.tr("Export your journal"))
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

                    // MARK: - Subscribe Button（朱砂主操作）
                    if selectedPackage != nil {
                        Button(action: purchase) {
                            HStack {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(DS.paperHi)
                                } else {
                                    Text(AppState.tr("Start Premium"))
                                        .fontWeight(.semibold)
                                        .tracking(3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button)
                                    .fill(DS.cinnabar)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.button)
                                    .stroke(DS.cinnabarDeep, lineWidth: 1.5)
                            )
                            .foregroundColor(DS.paperHi)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                            .shadow(color: DS.cinnabarDeep.opacity(0.4), radius: 10, y: 4)
                        }
                        .disabled(subscriptionManager.isLoading)

                        // 配了免费试用（RC intro offer）才显示——不硬编码，避免虚假宣传
                        if let pkg = selectedPackage,
                           let intro = pkg.storeProduct.introductoryDiscount,
                           intro.paymentMode == .freeTrial {
                            Text(AppState.tr("pw_trial_note"))
                                .font(.caption)
                                .foregroundColor(DS.nightSoft)
                                .transition(.opacity)
                        }
                    }

                    // MARK: - Restore + Footer
                    VStack(spacing: 8) {
                        Button(AppState.tr("Restore Purchases")) {
                            Task {
                                let restored = await subscriptionManager.restore()
                                restoreMessage = restored ? AppState.tr("Purchases restored!") : AppState.tr("No purchases found to restore.")
                                showRestoreAlert = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(DS.nightSoft)

                        // Terms/Privacy 挂 paywall 底部（Guideline 3.1.2 惯例，提升审核稳健性）
                        HStack(spacing: 14) {
                            Link(AppState.tr("Privacy Policy"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/privacy.html")!)
                            Text("·")
                            Link(AppState.tr("Terms of Service"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/terms.html")!)
                        }
                        .font(.caption2)
                        .foregroundColor(DS.nightSoft)

                        Text(AppState.tr("Subscription auto-renews unless cancelled at least 24h before the end of the period. Manage in App Store settings."))
                            .font(.caption2)
                            .foregroundColor(DS.nightSoft.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .background(
                ZStack {
                    DS.night.ignoresSafeArea()
                    // 夜的一角金光（右上的余晖）
                    RadialGradient(colors: [DS.bronze.opacity(0.18), .clear],
                                   center: UnitPoint(x: 0.85, y: 0.0),
                                   startRadius: 10, endRadius: 460)
                        .ignoresSafeArea()
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppState.tr("Close")) { dismiss() }
                        .foregroundColor(DS.nightSoft)
                }
            }
            .alert(AppState.tr("Restore"), isPresented: $showRestoreAlert) {
                Button(AppState.tr("OK")) {}
            } message: {
                Text(restoreMessage)
            }
            .task {
                // 2026-09-02 fix: 删掉 sync isPro check。SubscriptionManager.init() 启动时
                // 异步跑 refreshStatus()，如果用户已是 Pro，isPro 会在 .task 跑后
                // 100~500ms 内从 false 翻成 true，onChange(of: isPro) 已经处理 dismiss。
                // 不要再做"开局立刻 dismiss"，那会触发"paywall 闪一下就走"假象。
                Analytics.paywallView(context: context)
                await subscriptionManager.fetchOfferings()
                // 默认选中年档（价格锚点：把用户的起点放在最划算的选项上）；
                // 年档不存在（RC 后台配置异常）才退回第一顺位。
                if let packages = mergedPackages, !packages.isEmpty {
                    selectedPackage = packages.first(where: { $0.packageType == .annual }) ?? packages.first
                }
            }
            // Auto-dismiss when purchase succeeds OR user is already Pro.
            // 唯一 dismiss 入口：等 isPro 翻 true 主动 dismiss。
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
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(DS.nightGold.opacity(0.85))
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundColor(DS.nightSoft)
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
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(DS.nightGold)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DS.nightText)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(DS.nightText.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .stroke(DS.nightGold.opacity(0.22), lineWidth: 1)
        )
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
                    HStack(spacing: 7) {
                        // 标题统一为 "TaoMind Pro" 品牌（避免与 ASC product 名字耦合导致 lifetime 误显示为订阅）
                        Text(AppState.tr("pw_plan_brand"))
                            .font(DS.title(15))
                            .foregroundColor(DS.nightText)

                        if showBestValue {
                            // 「荐」朱砂小印（双语同形，异域感即品牌感）
                            Text(AppState.tr("pw_best_value"))
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(DS.paperHi)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 2).fill(DS.cinnabar))
                                .rotationEffect(.degrees(-2))
                        }
                    }

                    // 周期小字：lifetime / Annual / Quarterly / Monthly / Weekly / Six months / Daily，
                    // 所有档都显示（用户原话：每档下面一行小子）
                    Text(periodLabel)
                        .font(.caption)
                        .foregroundColor(DS.nightSoft)

                    // 价格锚点：长周期档折算月均价 + 相对月档省多少（"$3.33/mo · Save 58%"）
                    if let anchor = priceAnchor {
                        Text(anchor)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DS.nightGold)
                    }

                    // build 42: 年卡下面挂「N 天免费试用」小行（金印 + 文字）。
                    // 仅在 (a) 是年档 + (b) RC 后台真的配了 freeTrial intro offer 时显示，
                    // 避免硬编码「7 天」与实际配置不一致被 App Store 判虚假宣传。
                    // 天数从 introductoryDiscount.subscriptionPeriod 动态算出来。
                    if let trialLabel = trialLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption2)
                                .foregroundColor(DS.nightGold)
                            Text(trialLabel)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(DS.nightGold)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Text(package.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DS.nightText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(isSelected ? DS.cinnabar : DS.nightText.opacity(0.22), lineWidth: isSelected ? 1.5 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .fill(isSelected ? DS.cinnabar.opacity(0.10) : DS.night.opacity(0.55))
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

    /// 试用天数标签（仅在年档且 RC 后台配了 freeTrial intro offer 时返回文案）。
    /// 文案从 introductoryDiscount.subscriptionPeriod 动态算，避免硬编码"7"与配置不一致
    /// 被 App Store 判虚假宣传。1 周 → 7 天，1 月 → 30 天，1 年 → 365 天。
    private var trialLabel: String? {
        guard package.packageType == .annual,
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial,
              let period = intro.subscriptionPeriod else { return nil }
        let days: Int
        switch period.unit {
        case .day: days = period.value
        case .week: days = period.value * 7
        case .month: days = period.value * 30
        case .year: days = period.value * 365
        @unknown default: return nil
        }
        guard days > 0 else { return nil }
        return String(format: AppState.tr("pw_trial_xday_fmt"), days)
    }

    /// 每档下面一行的周期小字：lifetime / Annual / Quarterly / Six months / Monthly / Weekly / Daily
    private var periodLabel: String {
        if package.packageType == .lifetime {
            return AppState.tr("Lifetime")
        }
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        switch period.unit {
        case .month:
            switch period.value {
            case 1: return AppState.tr("Monthly")
            case 3: return AppState.tr("Quarterly")
            case 6: return AppState.tr("Semi-annual")
            case 2: return String(format: AppState.tr("every_n_months_fmt"), period.value)
            default: return String(format: AppState.tr("every_n_months_fmt"), period.value)
            }
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
