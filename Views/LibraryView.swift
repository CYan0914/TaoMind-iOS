import SwiftUI

// MARK: - Library (经藏)

struct LibraryView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var entries: [LibraryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEntry: LibraryEntry?
    @State private var selectedJingjiang: JingjiangChapter?
    @StateObject private var jingjiang = JingjiangService.shared

    private let api = APIClient()
    /// Free tier can read the first 5 chapters of each source as a taste.
    private let freeTasteCount = 5

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(AppState.tr("Retry")) {
                            Task { await load() }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(DS.ink)
                        .foregroundColor(.white)
                        .cornerRadius(DS.Radius.small)
                    }
                    .padding()
                } else {
                    libraryList
                }
            }
            .navigationTitle(AppState.tr("Library"))
            .paperBackground()
            .task {
                jingjiang.load()
                await load()
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LibraryDetailView(entry: entry)
            }
        }
        .sheet(item: $selectedJingjiang) { chapter in
            NavigationStack {
                JingjiangDetailView(chapter: chapter)
            }
        }
    }

    private var libraryList: some View {
        List {
            Section(header: Text(AppState.tr("library_tao_te_ching"))) {
                ForEach(ttcEntries) { entry in
                    libraryRow(entry)
                }
            }
            Section(header: Text(AppState.tr("library_diamond_sutra"))) {
                ForEach(diamondEntries) { entry in
                    libraryRow(entry)
                }
            }
            // 道德经·精讲：build 46 新增。原 5 章 free taste 模型不适用精讲（内容深度差异大），
            // 改成 1 章试读 + paywall(.)jingjiangLocked），让免费用户有"想继续看"的钩子
            if !jingjiang.chapters.isEmpty {
                Section {
                    ForEach(jingjiang.chapters) { chapter in
                        jingjiangRow(chapter)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.caption2)
                            .foregroundColor(DS.bronze)
                        Text(AppState.tr("library_jingjiang"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 修设计审计 2026-09-02 Blocker 2：List 底部加 100pt 透明 inset，
        // 让《金刚经》最后一章不被 iOS tab bar 切。
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
    }

    private func libraryRow(_ entry: LibraryEntry) -> some View {
        let locked = isLocked(entry)
        return Button {
            open(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.chapter)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.ink)
                    Text(entry.verse_text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    /// 精讲行：标题 + 通释片段 + 锁标。Pro 全部解锁；非 Pro 仅第 1 章免费。
    private func jingjiangRow(_ chapter: JingjiangChapter) -> some View {
        let locked = jingjiang.isLocked(chapter, isPro: subscriptionManager.isPro)
        return Button {
            openJingjiang(chapter, locked: locked)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(AppState.tr("chapter_fmt", chapter.num))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DS.ink)
                        if locked {
                            Text(AppState.tr("library_jingjiang_pro"))
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(DS.cinnabar.opacity(0.12))
                                .foregroundColor(DS.cinnabar)
                                .cornerRadius(3)
                        }
                    }
                    Text(chapter.localizedTongshi)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var ttcEntries: [LibraryEntry] { entries.filter { $0.source == "Tao Te Ching" } }
    private var diamondEntries: [LibraryEntry] { entries.filter { $0.source == "Diamond Sutra" } }

    private func isLocked(_ entry: LibraryEntry) -> Bool {
        guard !subscriptionManager.isPro else { return false }
        let sameSource = entries.filter { $0.source == entry.source }
        let index = sameSource.firstIndex { $0.display_order == entry.display_order } ?? 0
        return index >= freeTasteCount
    }

    private func open(_ entry: LibraryEntry) {
        if isLocked(entry) {
            subscriptionManager.openPaywall(.libraryLocked)
            return
        }
        selectedEntry = entry
    }

    private func openJingjiang(_ chapter: JingjiangChapter, locked: Bool) {
        if locked {
            subscriptionManager.openPaywall(.jingjiangLocked)
            return
        }
        selectedJingjiang = chapter
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.fetchLibrary()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                entries = result.entries
                isLoading = false
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
