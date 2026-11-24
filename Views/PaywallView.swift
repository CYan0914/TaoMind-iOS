import SwiftUI
import RevenueCat

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// 弹墙场景（决定顶部场景条文案；触发点通过 openPaywall(_:) 传入）
    let context: PaywallContext

    /// 引导页第 4 屏内嵌时用：关闭键由引导接管（要先写 hasSeenOnboarding 再落 tab）。
    /// nil = 常规 sheet，关闭即 dismiss。
    let onClose: (() -> Void)?

    /// 「先免费试 7 天」小字入口。nil 时不渲染（常规付费墙不重复承诺）。
    let onStartTrial: (() -> Void)?

    init(context: PaywallContext = .generic,
         onClose: (() -> Void)? = nil,
         onStartTrial: (() -> Void)? = nil) {
        self.context = context
        self.onClose = onClose
        self.onStartTrial = onStartTrial
    }

    @State private var selectedPackage: Package?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showPurchaseFailedAlert = false

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
        // 价格锚点：年档置顶（性价比最高）、终身档第二，其余按周期从长到短，
        // 月/周档垫底。零信任用户第一眼看到的是年档而不是终身价 —— 后者门槛最高。
        pkgs.sort { Self.anchorRank($0.packageType) < Self.anchorRank($1.packageType) }
        return pkgs
    }

    /// 年档居首、终身第二，其余周期从长到短。
    /// 2026-11-20 修正：此前实现把 lifetime 排 0、注释却写「年档置顶」，两者矛盾。
    /// 评审确认以「年档置顶」为准 —— 首屏心理门槛最低的方案拿第一顺位。
    private static func anchorRank(_ type: PackageType) -> Int {
        switch type {
        case .annual: return 0
        case .lifetime: return 1
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

                    // MARK: - Features
                    // 场景化：只展示与本次触顶最相关的三条。通用入口才给完整清单。
                    // 第一次看墙的人面对九条功能只会滑过去，三条才读得完。
                    VStack(spacing: 14) {
                        if let featured = context.featuredFeatures {
                            ForEach(Array(featured.enumerated()), id: \.offset) { _, feature in
                                HeroFeatureRow(icon: feature.icon,
                                               text: AppState.tr(feature.titleKey))
                            }
                        } else {
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

                        // 打卡换 7 天 Pro：付费墙是唯一能触达「还没养成打卡习惯」的用户的位置，
                        // 也是把「不想现在付钱」的人转成「先白拿 7 天试试」的最低门槛路径。
                        // 已领过就不显示，否则是在承诺一个不会再兑现的奖励。
                        if !subscriptionManager.hasClaimedTrial {
                            Text(AppState.tr("paywall_trial_hint"))
                                .font(.caption)
                                .foregroundColor(DS.nightSoft)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)

                            // 引导页内嵌时给一个可点的出口：不想现在付钱 → 先去打卡拿 7 天。
                            // 常规付费墙不传 onStartTrial，避免把「关闭」包装成转化路径。
                            if let onStartTrial {
                                Button(action: onStartTrial) {
                                    Text(AppState.tr("pw_start_trial"))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(DS.nightGold)
                                        .underline()
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel(AppState.tr("pw_start_trial"))
                            }
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
                        // FINDING-002：原来只有文字高度（约 13pt），远低于 44pt 命中区。
                        // 这是「付了钱没生效」的用户唯一能点的按钮。
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())

                        // Terms/Privacy 挂 paywall 底部（Guideline 3.1.2 惯例，提升审核稳健性）
                        HStack(spacing: 14) {
                            Link(AppState.tr("Privacy Policy"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/privacy.html")!)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            Text("·")
                            Link(AppState.tr("Terms of Service"),
                                 destination: URL(string: "https://cyan0914.github.io/taomind-privacy/terms.html")!)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .font(.caption2)
                        .foregroundColor(DS.nightSoft)

                        Text(AppState.tr("Subscription auto-renews unless cancelled at least 24h before the end of the period. Manage in App Store settings."))
                            .font(.caption2)
                            // FINDING-003：原来再叠 0.7 透明度 → 混合色 #8C8270 对夜底只有 4.41:1，
                            // 11pt 小字不达标。合规文案是全屏最需要读清的一行。
                            .foregroundColor(DS.nightSoft)
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
                    Button(AppState.tr("Close")) {
                        // 引导内嵌时交给引导收尾（先写 hasSeenOnboarding 再落 tab）
                        if let onClose { onClose() } else { dismiss() }
                    }
                    .foregroundColor(DS.nightSoft)
                    .accessibilityLabel(AppState.tr("Close"))
                }
            }
            .alert(AppState.tr("Restore"), isPresented: $showRestoreAlert) {
                Button(AppState.tr("OK")) {}
            } message: {
                Text(restoreMessage)
            }
            // 购买失败必须说出来：静默失败等于让用户以为 App 卡死。
            .alert(AppState.tr("purchase_failed_title"), isPresented: $showPurchaseFailedAlert) {
                Button(AppState.tr("OK")) {}
            } message: {
                Text(AppState.tr("purchase_failed_body"))
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
            // 唯一 dismiss 入口：等 isPro 翻 true 主动结束。
            // 引导内嵌时必须走 onClose，否则全屏引导关掉了但 hasSeenOnboarding 没写，
            // 下次启动又会弹一次引导。
            .onChange(of: subscriptionManager.isPro) { isPro in
                if isPro {
                    if let onClose { onClose() } else { dismiss() }
                }
            }
        }
    }

    private func purchase() {
        guard let pkg = selectedPackage else { return }
        Task {
            let outcome = await subscriptionManager.purchase(pkg)
            if outcome == .failed {
                showPurchaseFailedAlert = true
            }
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
        case .jingjiangLocked: return "book.closed.fill"
        case .backfill: return "calendar.badge.plus"
        case .monthlyReport: return "chart.line.uptrend.xyaxis"
        case .masterFeedback: return "person.wave.2"
        case .masterFollowup: return "bubble.left.and.text.bubble.right"
        case .journalExport: return "square.and.arrow.up"
        case .styleTuning: return "paintbrush"
        case .personalizedDailyVerse: return "sparkles"
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

    // 选中档反白后的三层文字色。朱砂底上用纸白（#FDFBF5，对比约 6.5:1），
    // 未选中仍是夜底上的暖白/灰褐/金。
    private var primaryText: Color { isSelected ? DS.paperHi : DS.nightText }
    private var secondaryText: Color { isSelected ? DS.paperHi.opacity(0.82) : DS.nightSoft }
    private var accentText: Color { isSelected ? DS.paperHi : DS.nightGold }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        // 标题统一为 "TaoMind Pro" 品牌（避免与 ASC product 名字耦合导致 lifetime 误显示为订阅）
                        Text(AppState.tr("pw_plan_brand"))
                            .font(DS.title(15))
                            .foregroundColor(primaryText)

                        if showBestValue {
                            // 「荐」小印：未选中时朱砂底纸白字；选中后整卡已是朱砂，
                            // 印必须反过来，否则和底色糊在一起。
                            Text(AppState.tr("pw_best_value"))
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(isSelected ? DS.cinnabar : DS.paperHi)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isSelected ? DS.paperHi : DS.cinnabar)
                                )
                                .rotationEffect(.degrees(-2))
                        }
                    }

                    // 周期小字：lifetime / Annual / Quarterly / Monthly / Weekly / Six months / Daily，
                    // 所有档都显示（用户原话：每档下面一行小子）
                    Text(periodLabel)
                        .font(.caption)
                        .foregroundColor(secondaryText)

                    // 价格锚点：长周期档折算月均价 + 相对月档省多少（"$3.33/mo · Save 58%"）
                    if let anchor = priceAnchor {
                        Text(anchor)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(accentText)
                    }

                    // build 42: 年卡下面挂「N 天免费试用」小行（金印 + 文字）。
                    // 仅在 (a) 是年档 + (b) RC 后台真的配了 freeTrial intro offer 时显示，
                    // 避免硬编码「7 天」与实际配置不一致被 App Store 判虚假宣传。
                    // 天数从 introductoryDiscount.subscriptionPeriod 动态算出来。
                    if let trialLabel = trialLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption2)
                                .foregroundColor(accentText)
                            Text(trialLabel)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(accentText)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Text(package.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
                    .monospacedDigit()
            }
            .padding()
            // 选中的档用实心朱砂反白：原来所有档都是"暗底 + 淡朱砂描边"，
            // 选中与未选中只差一点透明度，用户要在五档里找自己在哪一档。
            // 反白之后推荐档一眼可见，其余档退成安静的描边。
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(isSelected ? DS.cinnabar : DS.nightText.opacity(0.20), lineWidth: isSelected ? 1.5 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .fill(isSelected ? DS.cinnabar : DS.night.opacity(0.55))
                    )
            )
            .shadow(color: isSelected ? DS.cinnabarDeep.opacity(0.35) : .clear, radius: 12, y: 4)
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
    /// RC 5.14：introductoryDiscount.subscriptionPeriod 是 non-optional `SubscriptionPeriod`，
    /// 不需要 `if let`。
    private var trialLabel: String? {
        guard package.packageType == .annual,
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
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
