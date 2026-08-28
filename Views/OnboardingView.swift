import SwiftUI

// MARK: - Onboarding (首启 3 屏：价值预告 → 生活困惑 → 通知请求)

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var selectedIntent: ScenarioType?

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
                    notificationPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                pageIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                actionButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.light)
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

    // MARK: - Page 3: Notification request

    private var notificationPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(DS.bronze)

            Text(AppState.tr("One verse, every morning"))
                .font(DS.display(28, weight: .bold, relativeTo: .title2))
                .foregroundColor(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(AppState.tr("Get your daily verse, and a gentle nudge when your practice is slipping."))
                .font(.subheadline)
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
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
            VStack(spacing: 12) {
                primaryButton(title: AppState.tr("Enable Notifications"), enabled: true) {
                    NotificationService.shared.requestPermission()
                    finish()
                }
                Button {
                    finish()
                } label: {
                    Text(AppState.tr("Not now"))
                        .font(.subheadline)
                        .foregroundColor(muted)
                }
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
        dismiss()
    }
}
