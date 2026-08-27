import SwiftUI

// MARK: - Seek Wisdom View

struct SeekWisdomView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var question: String = ""
    @State private var selectedScenario: ScenarioType = .business_decision
    @State private var temperature: Double = 0.7
    @State private var isSeeking = false
    @State private var result: WisdomResponse?
    @State private var errorMessage: String?
    @State private var showDailyVerse = true
    @State private var showSpeechPermissionDenied = false
    @StateObject private var speechService = SpeechService()

    private let api = APIClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Daily Verse Banner
                if showDailyVerse, let verse = appState.dailyVerse {
                    DailyVerseCard(verse: verse)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { showDailyVerse.toggle() } }
                }

                // MARK: - Header
                VStack(spacing: 4) {
                    Text("☯")
                        .font(.system(size: 40))
                    Text("Seek Wisdom")
                        .font(.custom("Georgia", size: 28, relativeTo: .title))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    Text("Describe your situation. Receive ancient guidance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Free tier usage indicator
                    if !subscriptionManager.isPro {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(usageText)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 8)

                // MARK: - Scenario Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Context")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ScenarioType.allCases) { scenario in
                                ScenarioChip(
                                    scenario: scenario,
                                    isSelected: selectedScenario == scenario
                                ) {
                                    withAnimation { selectedScenario = scenario }
                                }
                            }
                        }
                    }
                }

                // MARK: - Question Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Situation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ZStack(alignment: .topLeading) {
                        if question.isEmpty {
                            Text(AppState.tr("Describe what you're facing... e.g., \n\"My team is burning out from constant deadlines...\""))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $question)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        // Voice input button — bottom trailing of the editor
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                micButton
                            }
                        }
                        .padding(10)
                    }

                    if speechService.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(AppState.tr("Recording…"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 4)

                // MARK: - Response Style (full tuning is Pro-only)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Response Style")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text(temperatureLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if subscriptionManager.isPro {
                        Slider(value: $temperature, in: 0.3...1.0, step: 0.1)
                            .tint(Color(red: 0.4, green: 0.3, blue: 0.18))
                    } else {
                        // Free tier: classic style only — tap to upgrade
                        Button(action: { subscriptionManager.openPaywall(.styleTuning) }) {
                            HStack(spacing: 8) {
                                Text(AppState.tr("Classic · Direct"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        Text(AppState.tr("upgrade_for_styles"))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 4)

                // MARK: - Seek Button
                Button(action: seekWisdom) {
                    HStack(spacing: 12) {
                        if isSeeking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isSeeking ? "Consulting the Sage..." : "Seek Wisdom")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        question.trimmingCharacters(in: .whitespaces).isEmpty || isSeeking
                            ? Color.gray.opacity(0.3)
                            : Color(red: 0.17, green: 0.14, blue: 0.09)
                    )
                    .foregroundColor(
                        question.trimmingCharacters(in: .whitespaces).isEmpty || isSeeking
                            ? .secondary
                            : .white
                    )
                    .cornerRadius(14)
                }
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isSeeking)

                // MARK: - Error
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                }

                // MARK: - Result
                if let result = result {
                    WisdomResultView(result: result, question: question, scenarioType: selectedScenario)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    // Pro 横幅（心流转化位：用户刚收到一次完整的智慧回应，价值感最高的一刻）
                    if !subscriptionManager.isPro {
                        Button(action: { subscriptionManager.openPaywall(.seekResult) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "crown.fill")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.72, green: 0.45, blue: 0.20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppState.tr("seek_banner_title"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                                    Text(AppState.tr("seek_banner_sub"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.08))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
                    .fontWeight(.semibold)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: result != nil)
        .sheet(isPresented: $subscriptionManager.showingPaywall) {
            PaywallView(context: subscriptionManager.paywallContext)
        }
        .alert(AppState.tr("Microphone access needed"), isPresented: $showSpeechPermissionDenied) {
            Button(AppState.tr("OK"), role: .cancel) {}
        } message: {
            Text(AppState.tr("Allow microphone and speech recognition in Settings to use voice input."))
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Voice Input

    private var micButton: some View {
        Button(action: toggleRecording) {
            Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(speechService.isRecording ? .white : Color(red: 0.4, green: 0.3, blue: 0.18))
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(speechService.isRecording ? Color.red : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppState.tr(speechService.isRecording ? "Stop recording" : "Voice input"))
        .opacity(speechService.isAvailable ? 1 : 0.4)
        .disabled(!speechService.isAvailable)
    }

    private func toggleRecording() {
        if speechService.isRecording {
            let transcript = speechService.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if question.isEmpty {
                    question = trimmed
                } else {
                    question += " " + trimmed
                }
            }
        } else {
            Task {
                guard await SpeechService.requestPermission() else {
                    showSpeechPermissionDenied = true
                    return
                }
                if !speechService.startRecording(localeId: appState.language.localeId) {
                    errorMessage = AppState.tr("Speech recognition isn't available here.")
                }
            }
        }
    }

    // MARK: - Actions

    private func seekWisdom() {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Check daily usage limit for free tier
        guard appState.canSeekWisdom else {
            subscriptionManager.openPaywall(.seekLimitToday)
            return
        }

        isSeeking = true
        errorMessage = nil
        result = nil

        let apiQuestion = question
        let apiScenario = selectedScenario.apiValue
        // Free tier is locked to the classic (direct) style
        let apiTemperature = subscriptionManager.isPro ? temperature : 0.4

        Task {
            do {
                let client = APIClient()
                let response = try await client.seekWisdom(
                    question: apiQuestion,
                    scenarioType: apiScenario,
                    temperature: apiTemperature,
                    language: appState.language.rawValue,
                    authToken: AuthService.shared.token
                )

                await MainActor.run {
                    result = response
                    isSeeking = false
                    appState.incrementDailyUsage()
                    Analytics.track("seek_completed", ["pro": subscriptionManager.isPro ? "1" : "0"])

                    // Auto-save to journal
                    saveToJournal(response: response)
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppState.tr("The sage is silent. Check your connection and try again.")
                    isSeeking = false
                }
            }
        }
    }

    /// Free tier journal entry cap (Pro is unlimited)
    static let freeJournalLimit = 20

    private func saveToJournal(response: WisdomResponse) {
        Task {
            do {
                // Free tier: cap journal at freeJournalLimit entries — prompt upgrade when full
                if !subscriptionManager.isPro {
                    let existing = try await api.listJournal(limit: 50)
                    if existing.count >= Self.freeJournalLimit {
                        await MainActor.run {
                            subscriptionManager.openPaywall(.journalFull)
                        }
                        print("[Journal] Free tier limit reached (\(Self.freeJournalLimit)) — entry not saved")
                        return
                    }
                }

                let client = APIClient()
                _ = try await client.saveJournal(
                    question: question,
                    scenarioType: selectedScenario.apiValue,
                    passage: response.passage,
                    wisdom: response.wisdom,
                    reflection: response.reflection,
                    wayForward: response.way_forward
                )
            } catch {
                // Silent fail — journal save is non-critical
                print("Failed to save journal: \(error)")
            }
        }
    }

    private var temperatureLabel: String {
        switch temperature {
        case ..<0.5: return AppState.tr("Classic · Direct")
        case ..<0.8: return AppState.tr("Balanced")
        default: return AppState.tr("Reflective · Poetic")
        }
    }

    private var usageText: String {
        if appState.seeksRemainingToday == Int.max {
            return AppState.tr("Unlimited free today")
        }
        return String(format: AppState.tr("free_today_fmt"), appState.seeksRemainingToday)
    }
}

// MARK: - Scenario Chip

struct ScenarioChip: View {
    let scenario: ScenarioType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: scenario.icon)
                    .font(.caption)
                Text(AppState.tr(scenario.rawValue))
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color(red: 0.17, green: 0.14, blue: 0.09)
                    : Color(.systemGray6)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}
