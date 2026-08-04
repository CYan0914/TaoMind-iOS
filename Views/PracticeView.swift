import SwiftUI
import AuthenticationServices

// MARK: - Daily Practice (每日功课)

struct PracticeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authService: AuthService

    @State private var source: String = "verse"        // "verse" | "wisdom"
    @State private var reflection: String = ""
    @State private var status: CheckinListResponse?
    @State private var feedback: String?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isAskingMaster = false
    @State private var isEditingToday = false
    @State private var errorMessage: String?
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput: String = ""
    @State private var isSendingChat = false
    @State private var showBackfill = false
    @State private var milestone: MilestoneInfo?
    @State private var shareCardContent: ShareCardContent?

    private let service = CheckinService()

    var body: some View {
        Group {
            if authService.isSignedIn {
                practiceContent
            } else {
                signedOutContent
            }
        }
        .navigationTitle("Practice")
        .task {
            if authService.isSignedIn {
                await loadStatus()
            }
        }
        .onChange(of: authService.isSignedIn) { signedIn in
            if signedIn {
                Task { await loadStatus() }
            }
        }
        .sheet(isPresented: $showBackfill) {
            if let date = status?.backfill?.targetDate {
                BackfillView(targetDate: date) {
                    Task { await loadStatus() }
                }
            }
        }
        .sheet(item: $milestone) { m in
            MilestoneCelebrationView(milestone: m, isChinese: appState.language == .chinese) {
                shareMilestone(m)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $shareCardContent) { content in
            ShareCardPreviewSheet(content: content)
        }
    }

    // MARK: - Signed out

    private var signedOutContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 30)
                Text("☯")
                    .font(.system(size: 56))
                Text("Daily Practice")
                    .font(.custom("Georgia", size: 24, relativeTo: .title2))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                Text("Read today's verse, reflect, and keep your streak. Sign in to sync across devices.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            _ = await authService.handleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .padding(.horizontal, 32)
                .disabled(authService.isAuthenticating)

                if authService.isAuthenticating {
                    ProgressView()
                }

                if let err = authService.authError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.top, 40)
        }
    }

    // MARK: - Signed in content

    private var practiceContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Streak header
                streakHeader

                // Streak actions (backfill + share card)
                streakActions

                // Today's verse
                if let verse = appState.dailyVerse {
                    DailyVerseCard(verse: verse)
                }

                // Source picker
                sourcePicker

                // Reflection input
                reflectionInput

                // Save / status
                if let today = status?.today, !isEditingToday {
                    savedStateCard(today)
                } else {
                    saveButton
                }

                // Master guidance (Pro)
                if let today = status?.today {
                    masterGuidanceSection(today)
                }

                // Recent history
                if let checkins = status?.checkins, !checkins.isEmpty {
                    historySection(checkins)
                }
            }
            .padding()
        }
        .overlay(alignment: .top) {
            if errorMessage != nil {
                errorBanner
            }
        }
    }

    // MARK: - Sections

    private var streakHeader: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("🔥")
                    .font(.title2)
                Text("\(status?.streak.currentStreak ?? 0)")
                    .font(.custom("Georgia", size: 32, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                Text(AppState.tr("streak_days"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(AppState.tr("best_streak"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(status?.streak.longestStreak ?? 0) \(AppState.tr("days"))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(AppState.tr("total_checkins_fmt", status?.streak.totalCheckins ?? 0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(AppState.tr("today"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: (status?.streak.todayDone ?? false) ? "checkmark.seal.fill" : "circle")
                    .font(.title3)
                    .foregroundColor((status?.streak.todayDone ?? false) ? .green : .secondary)
                Text(AppState.tr("signed_in_as", authService.user?.display_name ?? authService.user?.email ?? ""))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.6))
        .cornerRadius(14)
    }

    // MARK: - Streak actions (补卡 + 分享)

    private var streakActions: some View {
        HStack(spacing: 12) {
            if let bf = status?.backfill, bf.available, !(status?.streak.todayDone ?? false) {
                Button(action: openBackfill) {
                    Label(AppState.tr("Backfill"), systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                }
            }
            Button(action: shareStreak) {
                Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func openBackfill() {
        guard subscriptionManager.isPro else {
            subscriptionManager.showingPaywall = true
            return
        }
        showBackfill = true
    }

    private func shareStreak() {
        guard subscriptionManager.isPro else {
            subscriptionManager.showingPaywall = true
            return
        }
        let days = status?.streak.currentStreak ?? 0
        let verse = appState.dailyVerse.map { $0.verse_text } ?? ""
        shareCardContent = ShareCardContent(
            title: String(format: AppState.tr("streak_days_fmt"), days),
            verse: verse,
            note: "",
            subtitle: AppState.tr("share_card_subtitle")
        )
    }

    // MARK: - Milestone detection

    private func checkMilestone() {
        guard let streak = status?.streak else { return }
        let current = streak.currentStreak
        guard current > 0 else { return }
        let shown = Set(UserDefaults.standard.array(forKey: "shownMilestones") as? [Int] ?? [])
        guard let reached = MilestoneInfo.all.filter({ $0.days <= current }).last,
              !shown.contains(reached.days) else { return }
        milestone = reached
        var updated = shown
        updated.insert(reached.days)
        UserDefaults.standard.set(Array(updated), forKey: "shownMilestones")
    }

    private func shareMilestone(_ m: MilestoneInfo) {
        guard subscriptionManager.isPro else {
            subscriptionManager.showingPaywall = true
            return
        }
        let zh = appState.language == .chinese
        shareCardContent = ShareCardContent(
            title: String(format: AppState.tr("streak_days_fmt"), m.days),
            verse: zh ? m.quoteZh : m.quoteEn,
            note: zh ? m.titleZh : m.titleEn,
            subtitle: AppState.tr("share_card_subtitle")
        )
    }

    private var sourcePicker: some View {
        HStack(spacing: 10) {
            sourceChip("📖", AppState.tr("read_verse"), selected: source == "verse") {
                source = "verse"
            }
            sourceChip("☯", AppState.tr("seek_wisdom_short"), selected: source == "wisdom") {
                source = "wisdom"
            }
        }
    }

    private func sourceChip(_ icon: String, _ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(selected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(selected ? Color(red: 0.17, green: 0.14, blue: 0.09) : Color(.systemGray6))
            .foregroundColor(selected ? .white : .primary)
            .cornerRadius(12)
        }
    }

    private var reflectionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Reflection")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(AppState.tr("write_once_daily"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if reflection.isEmpty {
                    Text(AppState.tr("reflection_placeholder"))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $reflection)
                    .font(.body)
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }

    private var saveButton: some View {
        Button(action: savePractice) {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.seal")
                }
                Text(AppState.tr("complete_practice"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(reflection.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray.opacity(0.3)
                        : Color(red: 0.17, green: 0.14, blue: 0.09))
            .foregroundColor(reflection.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .white)
            .cornerRadius(14)
        }
        .disabled(reflection.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
    }

    private func savedStateCard(_ today: Checkin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(AppState.tr("practice_done_today"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Spacer()
                Button {
                    // Allow rewriting today's reflection
                    reflection = today.reflection
                    isEditingToday = true
                } label: {
                    Text(AppState.tr("edit"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text(today.reflection)
                .font(.custom("Georgia", size: 15, relativeTo: .body))
                .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
        }
        .padding()
        .background(Color.green.opacity(0.06))
        .cornerRadius(14)
    }

    @ViewBuilder
    private func masterGuidanceSection(_ today: Checkin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(AppState.tr("master_guidance"), systemImage: "person.crop.circle.badge.questionmark")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                Spacer()
                if !subscriptionManager.isPro {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Master's guidance (current session or persisted)
            if let current = currentFeedback {
                masterBubble(current)
            }

            // Ask button — only when no guidance yet
            if currentFeedback == nil {
                if subscriptionManager.isPro {
                    askMasterButton(title: AppState.tr("ask_master"), showsTaste: false)
                } else if !weeklyFreeMasterUsed {
                    askMasterButton(title: AppState.tr("master_free_try"), showsTaste: true)
                } else {
                    lockedMasterButton
                }
            }

            // Follow-up conversation — appears once guidance exists
            if currentFeedback != nil {
                followUpSection
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Master guidance helpers

    private var currentFeedback: String? {
        if let f = feedback, !f.isEmpty { return f }
        if let mf = status?.today?.master_feedback, !mf.isEmpty { return mf }
        return nil
    }

    private func masterBubble(_ text: String) -> some View {
        Text(text)
            .font(.custom("Georgia", size: 15, relativeTo: .body))
            .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
            .lineSpacing(6)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.7))
            .cornerRadius(10)
    }

    private func askMasterButton(title: String, showsTaste: Bool) -> some View {
        Button(action: askMaster) {
            HStack(spacing: 10) {
                if isAskingMaster {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: showsTaste ? "sparkles" : "wand.and.stars")
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(red: 0.17, green: 0.14, blue: 0.09))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isAskingMaster)
    }

    private var lockedMasterButton: some View {
        Button(action: { subscriptionManager.showingPaywall = true }) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text(AppState.tr("master_locked"))
                    .font(.subheadline)
                Spacer()
                Text(AppState.tr("Upgrade"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .foregroundColor(.secondary)
            .cornerRadius(12)
        }
    }

    // MARK: - Free tier master taste (每周 1 次免费名师指点)

    private var weeklyMasterKey: String {
        let comps = Calendar(identifier: .gregorian).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
    }

    private var weeklyFreeMasterUsed: Bool {
        UserDefaults.standard.string(forKey: "weeklyFreeMasterUsedKey") == weeklyMasterKey
    }

    private func markWeeklyFreeMasterUsed() {
        UserDefaults.standard.set(weeklyMasterKey, forKey: "weeklyFreeMasterUsedKey")
    }

    // MARK: - Follow-up chat (名师追问)

    @ViewBuilder
    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if subscriptionManager.isPro {
                ForEach(chatMessages) { msg in
                    chatBubble(msg)
                }
                HStack(spacing: 8) {
                    TextField(AppState.tr("master_followup_placeholder"), text: $chatInput, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    Button(action: sendChat) {
                        if isSendingChat {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(
                                    chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.gray.opacity(0.4)
                                        : Color(red: 0.17, green: 0.14, blue: 0.09)
                                )
                        }
                    }
                    .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingChat)
                }
            } else {
                // Locked follow-up — the conversion moment
                Button(action: { subscriptionManager.showingPaywall = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.caption)
                        Text(AppState.tr("master_followup_locked"))
                            .font(.subheadline)
                        Spacer()
                        Text(AppState.tr("Upgrade"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .foregroundColor(.secondary)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack(spacing: 10) {
            if isUser { Spacer(minLength: 48) }
            Text(msg.content)
                .font(.custom("Georgia", size: 15, relativeTo: .body))
                .foregroundColor(isUser ? .white : Color(red: 0.25, green: 0.22, blue: 0.16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color(red: 0.17, green: 0.14, blue: 0.09) : Color.white.opacity(0.7))
                .cornerRadius(14)
            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
    }

    private func persistChat(for checkinId: Int) {
        let key = "masterChat.\(checkinId)"
        if let data = try? JSONEncoder().encode(chatMessages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadChat(for checkinId: Int) {
        let key = "masterChat.\(checkinId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            chatMessages = saved
        }
    }

    private func historySection(_ checkins: [Checkin]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppState.tr("recent_practice"))
                .font(.headline)
                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))

            ForEach(Array(checkins.prefix(7))) { checkin in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(checkin.checkin_date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(checkin.reflection)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if checkin.master_feedback != nil && !(checkin.master_feedback ?? "").isEmpty {
                        Image(systemName: "person.crop.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(errorMessage ?? "")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            status = try await service.fetchStatus()
            // Sync the persisted feedback into today's checkin if present
            if let today = status?.today, let fb = today.master_feedback, !fb.isEmpty {
                feedback = fb
                loadChat(for: today.id)
            }
            checkMilestone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePractice() {
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        Task {
            do {
                let verseText = appState.dailyVerse.map {
                    "\($0.source) · \($0.chapter): \($0.verse_text)"
                } ?? ""
                let result = try await service.saveCheckin(
                    source: source,
                    verseText: verseText,
                    reflection: text
                )
                await MainActor.run {
                    status = CheckinListResponse(checkins: status?.checkins ?? [], today: result.checkin, streak: result.streak)
                    reflection = ""
                    isEditingToday = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            isSaving = false
        }
    }

    private func askMaster() {
        guard let today = status?.today else { return }
        // Free tier: one free master guidance per week — beyond that, paywall
        if !subscriptionManager.isPro && weeklyFreeMasterUsed {
            subscriptionManager.showingPaywall = true
            return
        }
        isAskingMaster = true
        Task {
            do {
                let language = appState.language.rawValue
                let result = try await service.requestFeedback(checkinId: today.id, language: language)
                await MainActor.run {
                    feedback = result.feedback
                    // Only consume the free taste when the server actually generated
                    // new feedback (not a cached replay of a previous guidance).
                    if !subscriptionManager.isPro && result.cached != true {
                        markWeeklyFreeMasterUsed()
                    }
                    errorMessage = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            isAskingMaster = false
        }
    }

    private func sendChat() {
        guard let today = status?.today else { return }
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSendingChat else { return }
        chatInput = ""
        chatMessages.append(ChatMessage(role: "user", content: text))
        isSendingChat = true
        Task {
            do {
                let history = Array(chatMessages.dropLast())
                let result = try await service.sendMasterChat(
                    checkinId: today.id,
                    message: text,
                    history: history,
                    language: appState.language.rawValue
                )
                await MainActor.run {
                    chatMessages.append(ChatMessage(role: "master", content: result.reply))
                    persistChat(for: today.id)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            isSendingChat = false
        }
    }
}
