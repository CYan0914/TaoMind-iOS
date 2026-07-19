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
                            Text("\(appState.seeksRemainingToday == Int.max ? "∞" : "\(appState.seeksRemainingToday)") free today")
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
                            Text("Describe what you're facing... e.g., \n\"My team is burning out from constant deadlines...\"")
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
                    }
                }
                .padding(.horizontal, 4)

                // MARK: - Temperature Slider
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

                    Slider(value: $temperature, in: 0.3...1.0, step: 0.1)
                        .tint(Color(red: 0.4, green: 0.3, blue: 0.18))
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
            PaywallView()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Actions

    private func seekWisdom() {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Check daily usage limit for free tier
        guard appState.canSeekWisdom else {
            subscriptionManager.showingPaywall = true
            return
        }

        isSeeking = true
        errorMessage = nil
        result = nil

        let apiQuestion = question
        let apiScenario = selectedScenario.apiValue

        Task {
            do {
                let client = APIClient()
                let response = try await client.seekWisdom(
                    question: apiQuestion,
                    scenarioType: apiScenario,
                    temperature: temperature,
                    language: appState.language.rawValue
                )

                await MainActor.run {
                    result = response
                    isSeeking = false
                    appState.incrementDailyUsage()

                    // Auto-save to journal
                    saveToJournal(response: response)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "The sage is silent. Check your connection and try again."
                    isSeeking = false
                }
            }
        }
    }

    private func saveToJournal(response: WisdomResponse) {
        Task {
            do {
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
        case ..<0.5: return "Classic · Direct"
        case ..<0.8: return "Balanced"
        default: return "Reflective · Poetic"
        }
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
                Text(scenario.rawValue)
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
