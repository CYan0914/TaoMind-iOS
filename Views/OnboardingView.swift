import SwiftUI

// MARK: - Onboarding（首启 4 屏：价值预告 → 生活困惑 → 首次解读 → 付费墙）
//
// 2026-11-24 改版：原来的第 3 屏「通知请求」删掉，换成「首次解读」，
// 并把付费墙作为第 4 屏直接接在引导末尾。
//
// 为什么这么排：
//   ① 旧流程走完引导直接进免费功能，付费墙只在撞额度时才出现（惩罚型时机）；
//      新流程让用户先拿到一次真实解读，紧接着看到墙（趁热型时机）。
//   ② 第 3 屏读的就是用户第 2 屏选的困惑，个性化从第一分钟成立。
//   ③ 通知权限请求挪出首启 —— 首启要权限通过率极低，还打断「体验→付费」的热链路。
//      权限改到用户第一次完成打卡后再要（PracticeView 打卡完成态负责）。
//
// 第 3 屏那次解读**不占用户每天 3 次免费额度**（2026-11-24 用户定）：
//   APIClient 调用时**不传 authToken** → 服务端按匿名 IP 限额计，不落到用户头上。
//   代价是同一 WiFi 下大量新用户可能撞 20 次/天的匿名上限，所以必须有本地兜底样本。

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var selectedIntent: ScenarioType?

    // 第 3 屏：首次解读
    @State private var preview: WisdomResponse?
    @State private var isLoadingPreview = false
    @State private var previewFailed = false
    @State private var previewRequested = false

    private let ink = DS.ink
    private let paper = DS.paper
    private let muted = DS.inkSoft

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    valuePage.tag(0)
                    intentPage.tag(1)
                    previewPage.tag(2)
                    paywallPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                // 付费墙整屏自带关闭键，不再叠引导的页码与按钮
                if page < 3 {
                    pageIndicator
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    actionButton
                        .padding(.horizontal, 28)
                        .padding(.bottom, 36)
                }
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: page) { newPage in
            // 进到第 3 屏才请求，避免首次启动就打一次没人看的 LLM
            if newPage == 2 { loadPreviewIfNeeded() }
        }
    }

    // MARK: - Page 1: Value preview

    private var valuePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // 竖排装饰题字（品牌元素：道法自然）
                Text("道法自然")
                    .font(DS.display(64, weight: .black, relativeTo: .largeTitle))
                    .foregroundColor(DS.ink.opacity(0.07))
                    .lineSpacing(10)
                    .padding(.trailing, 18)
                VStack(spacing: 10) {
                    Text("TaoMind")
                        .font(DS.verse(40, relativeTo: .largeTitle))
                        .fontWeight(.semibold)
                        .foregroundColor(ink)
                    Text(AppState.tr("Ancient wisdom for today"))
                        .eyebrowStyle()
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                valueRow(icon: "book", title: AppState.tr("A new verse every day"),
                         detail: AppState.tr("Tao Te Ching and Diamond Sutra, one chapter at a time"))
                valueRow(icon: "sparkles", title: AppState.tr("Ask the sage about anything"),
                         detail: AppState.tr("Get guidance rooted in 2,500-year-old wisdom"))
                valueRow(icon: "flame", title: AppState.tr("Build a practice that sticks"),
                         detail: AppState.tr("Daily check-ins, streaks and gentle reminders"))
            }
            .padding(.horizontal, 32)

            // 社交证明：放在价值点之后，制造"很多人已经在用"暗示
            Text(AppState.tr("onboarding_social_proof"))
                .font(.subheadline)
                .foregroundColor(DS.bronze)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 48)
    }

    // MARK: - Page 2: Personalization hook

    private var intentPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(AppState.tr("What do you most want to solve right now?"))
                .font(.custom("Georgia", size: 26, relativeTo: .title2))
                .fontWeight(.semibold)
                .foregroundColor(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(AppState.tr("Your choice shapes your first day's guidance."))
                .font(.subheadline)
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // 5 life-confusion options (same scenarios as Seek Wisdom)
            VStack(spacing: 12) {
                ForEach(ScenarioType.allCases) { scenario in
                    intentRow(scenario)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.top, 40)
    }

    // MARK: - Page 3: First real reading

    private var previewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 眉标 + 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppState.tr("ob_preview_eyebrow"))
                        .eyebrowStyle()
                    Text(AppState.tr("ob_preview_title"))
                        .font(DS.display(27, weight: .bold, relativeTo: .title2))
                        .foregroundColor(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AppState.tr("ob_preview_sub"))
                        .font(.subheadline)
                        .foregroundColor(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 用户选的困惑（证明这是为他算的）
                if let intent = selectedIntent {
                    HStack(spacing: 10) {
                        Image(systemName: intent.icon)
                            .font(.subheadline)
                            .foregroundColor(DS.bronzeDeep)
                        Text(AppState.tr(intent.rawValue))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ink)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.small)
                            .fill(DS.bronze.opacity(0.08))
                    )
                }

                if let preview = preview {
                    readingCard(preview)
                } else if isLoadingPreview {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(AppState.tr("ob_preview_loading"))
                            .font(.footnote)
                            .foregroundColor(muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if previewFailed {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("ob_preview_failed"))
                            .font(.subheadline)
                            .foregroundColor(muted)
                        Button(AppState.tr("Retry")) {
                            previewRequested = false
                            loadPreviewIfNeeded()
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.cinnabar)
                    }
                    .padding(.vertical, 24)
                }

                // 锁住的后半段：让用户知道完整解读还有什么
                VStack(spacing: 10) {
                    lockedRow(icon: "text.magnifyingglass",
                              text: AppState.tr("ob_preview_locked_reflection"))
                    lockedRow(icon: "arrow.turn.down.right",
                              text: AppState.tr("ob_preview_locked_way"))
                    lockedRow(icon: "bubble.left.and.text.bubble.right",
                              text: AppState.tr("ob_preview_locked_followup"))
                }

                Text(AppState.tr("ob_preview_free_note"))
                    .font(.caption)
                    .foregroundColor(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }

    /// 解读卡：只展示原文 + 一句「老子怎么说」，其余折叠在锁后面。
    private func readingCard(_ response: WisdomResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppState.tr("The Passage").uppercased())
                .font(DS.eyebrowFont)
                .tracking(DS.eyebrowTracking)
                .foregroundColor(DS.bronzeDeep)

            Text(response.passage)
                .font(DS.verse(19, relativeTo: .body))
                .foregroundColor(ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(DS.bronze.opacity(0.25))

            Text(AppState.tr("The Wisdom").uppercased())
                .font(DS.eyebrowFont)
                .tracking(DS.eyebrowTracking)
                .foregroundColor(DS.bronzeDeep)

            Text(response.wisdom)
                .font(.body)
                .foregroundColor(DS.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.paperHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.bronze.opacity(0.18), lineWidth: 1)
        )
    }

    private func lockedRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(DS.inkFaint)
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundColor(DS.inkSoft)
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(DS.inkFaint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(DS.ink.opacity(0.03))
        )
    }

    // MARK: - Page 4: Paywall

    private var paywallPage: some View {
        PaywallView(
            context: .seekResult,
            onClose: { finish() },
            onStartTrial: { finish() }
        )
    }

    // MARK: - Preview loading

    private func loadPreviewIfNeeded() {
        guard !previewRequested else { return }
        previewRequested = true
        isLoadingPreview = true
        previewFailed = false

        let scenario = selectedIntent ?? .business_decision
        let question = Self.previewQuestion(for: scenario)
        let language = appState.language.rawValue

        Task {
            do {
                // ⚠️ 刻意不传 authToken：这次解读走匿名限额，不消耗用户每天 3 次额度
                let response = try await APIClient().seekWisdom(
                    question: question,
                    scenarioType: scenario.apiValue,
                    temperature: 0.4,
                    language: language,
                    authToken: nil
                )
                await MainActor.run {
                    preview = response
                    isLoadingPreview = false
                }
            } catch {
                await MainActor.run {
                    // 匿名通道撞 IP 限额 / 断网 → 用本地样本，别让引导页卡在转圈
                    preview = Self.fallbackReading(for: scenario, isEnglish: language == "en")
                    previewFailed = preview == nil
                    isLoadingPreview = false
                }
            }
        }
    }

    private static func previewQuestion(for scenario: ScenarioType) -> String {
        switch scenario {
        case .business_decision:
            return "I keep going back and forth on one business decision and I can't commit."
        case .leadership:
            return "My team is drifting and I can't tell whether to push harder or step back."
        case .career:
            return "I want to move forward in my career, but I'm afraid of losing what I already have."
        case .personal:
            return "Something in my personal life has been weighing on me for weeks."
        case .conflict:
            return "Someone close to me and I are stuck in a conflict, and neither of us will move."
        }
    }

    /// 本地兜底样本（匿名通道失败时用）。每条约 2 句，够撑住第 3 屏的形制。
    private static func fallbackReading(for scenario: ScenarioType, isEnglish: Bool) -> WisdomResponse? {
        let pair: (zh: String, en: String, wisdomZh: String, wisdomEn: String)
        switch scenario {
        case .business_decision:
            pair = ("知足不辱，知止不殆，可以长久。",
                    "Knowing when enough is enough keeps you from disgrace; knowing when to stop keeps you from danger. This is how you last.",
                    "你迟迟定不下来，多半是因为没给自己一个「到此为止」的条件。先定停手线，再定选项。",
                    "You are stuck because you never set a stopping condition. Decide when to stop first, then choose.")
        case .leadership:
            pair = ("太上，下知有之；其次，亲而誉之；其次，畏之；其次，侮之。",
                    "The best leader is barely noticed. The next is loved and praised. The next is feared. The worst is mocked.",
                    "团队散了，先别加大力度。最好的带领是让人几乎感觉不到你在推。",
                    "When the team drifts, do not push harder. The best leading is the kind people barely notice.")
        case .career:
            pair = ("千里之行，始于足下。",
                    "A journey of a thousand miles begins beneath your feet.",
                    "你想动，又怕失去现有的。先做一件本周就能完成的小动作，而不是先辞职。",
                    "You want to move but fear losing what you have. Do one small thing this week, not a resignation.")
        case .personal:
            pair = ("上善若水。水善利万物而不争。",
                    "The highest good is like water: it benefits all things without competing.",
                    "这件事越用力越僵。先退半步，让它自己露出形状。",
                    "The harder you grip this, the stiffer it gets. Step back half a pace and let it show its shape.")
        case .conflict:
            pair = ("夫唯不争，故天下莫能与之争。",
                    "It is because he does not contend that no one in the world can contend with him.",
                    "你不需要赢这一场。先停止证明自己是对的，僵局才有缝。",
                    "You do not need to win this one. Stop proving you are right, and the deadlock opens.")
        }
        return WisdomResponse(
            passage: isEnglish ? pair.en : pair.zh,
            wisdom: isEnglish ? pair.wisdomEn : pair.wisdomZh,
            reflection: "",
            way_forward: ""
        )
    }

    // MARK: - Bottom controls

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i == page ? DS.cinnabar : DS.ink.opacity(0.15))
                    .frame(width: i == page ? 18 : 6, height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    @ViewBuilder
    private var actionButton: some View {
        if page == 0 {
            primaryButton(title: AppState.tr("Continue")) { withAnimation { page = 1 } }
        } else if page == 1 {
            primaryButton(title: AppState.tr("Continue"),
                          enabled: selectedIntent != nil) {
                // 记录生活困惑方向（随当日打卡传给后端，影响第一天名师指点）
                if let intent = selectedIntent {
                    appState.userIntent = intent.apiValue
                }
                withAnimation { page = 2 }
            }
        } else {
            primaryButton(title: AppState.tr("Continue")) {
                withAnimation { page = 3 }
            }
        }
    }

    private func primaryButton(title: String, enabled: Bool = true,
                               action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.headline)
                .tracking(3)
                .foregroundColor(enabled ? DS.paperHi : DS.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button)
                        .fill(enabled ? DS.cinnabar : DS.ink.opacity(0.12))
                )
        }
        .disabled(!enabled)
    }

    // MARK: - Row helpers

    private func valueRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ink)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(muted)
            }
        }
    }

    private func intentRow(_ scenario: ScenarioType) -> some View {
        let isSelected = selectedIntent == scenario
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedIntent = scenario }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: scenario.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? DS.paperHi : DS.bronze)
                    .frame(width: 30)
                Text(AppState.tr(scenario.rawValue))
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? DS.paperHi : ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DS.paperHi)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(isSelected ? DS.ink : DS.paperHi)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .stroke(isSelected ? Color.clear : DS.bronze.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func finish() {
        appState.hasSeenOnboarding = true
        // 新用户第一屏落在 Practice（今日经文 + 打卡），而不是 AI 求问页：
        // 习惯养成从「今天读一句、记一笔」起步，先读经文再看别的。
        appState.selectedTab = 3
        dismiss()
    }
}
