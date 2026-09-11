import SwiftUI

// MARK: - Journal View

/// 单一 sheet 驱动 —— 修 bug 2026-09-10。
///
/// 原来 `showDetail` 和 `showExport` 是**两个 `.sheet(isPresented:)` 挂在同一视图上**，
/// SwiftUI 对同层多 sheet 的处理是未定义的：点条目时详情 sheet 会弹出但内容空白
/// （呈现时机与另一个 sheet 的绑定互相干扰）。
/// 本项目 2026-09-02 已在 SeekWisdomView / SettingsView 踩过同类坑（见 SeekWisdomView:271）。
/// 改成一个 `.sheet(item:)` + enum，从根上消除多 sheet 冲突；
/// 顺带干掉了 `selectedEntry` + `showDetail` 双状态竞态（前者 nil 时 sheet 就是空白）。
private enum JournalSheet: Identifiable {
    case detail(JournalEntry)
    case export

    var id: String {
        switch self {
        case .detail(let entry): return "detail-\(entry.id)"
        case .export: return "export"
        }
    }
}

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeSheet: JournalSheet?

    private let api = APIClient()

    /// 免费版剩余可存条数（0 = 已满；历史条目可能超 20，clamp 到 0）
    private var journalSlotsLeft: Int {
        max(SeekWisdomView.freeJournalLimit - entries.count, 0)
    }

    private var bannerText: String {
        if journalSlotsLeft == 0 {
            return AppState.tr("journal_full_now")
        }
        return String(format: AppState.tr("journal_slots_left_fmt"), journalSlotsLeft, SeekWisdomView.freeJournalLimit)
    }

    var body: some View {
        Group {
            if isLoading {
                // build 34: 撑满整屏让外层 .paperBackground 真正铺到 loading 区，
                // 否则 Group 子视图没 Spacer 时背景只盖在最小边界上 → 加载中显白。
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading your journal...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Task { await loadEntries() }
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
            } else if entries.isEmpty {
                // build 44: 撑满整屏让外层 .paperBackground 真正铺到空状态区域。
                // 没 Spacer 时 VStack 按内容最小尺寸渲染 → 背景只盖在文字块上，
                // 周围一圈是 NavigationStack 默认白色 → 丑。
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "book")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(AppState.tr("Your Journal is Empty"))
                        .font(.custom("Georgia", size: 20, relativeTo: .title2))
                        .fontWeight(.semibold)
                        .foregroundColor(DS.ink)
                    Text("Every wisdom session is saved here.\nGo seek wisdom to fill your journal.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    // Free tier: journal limit banner（动态剩余额度——越接近上限越有紧迫感）
                    if !subscriptionManager.isPro {
                        Section {
                            Button(action: { subscriptionManager.openPaywall(.journalFull) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: journalSlotsLeft == 0 ? "exclamationmark.triangle.fill" : "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(bannerText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(AppState.tr("Upgrade"))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(DS.ink)
                                }
                            }
                            // 修 UI 一致性 2026-09-10（v3，前两版都错）：
                // ⚠️ listRowBackground 是**行级**修饰符 —— 加在 List 上是 no-op（v1 错这里）。
                // ⚠️ v2 用了 DS.paper（= 页面底色）→ 行与背景完全同色，卡片"消失"，比白色更糟。
                // ✅ 正解 DS.paperHi（卡纸色 #FDFBF5，比页面底 #F4EFE3 略亮），与「功课」页的
                //    心情 chip（MoodChipRow）、经藏入口卡、珍藏卡一致 —— 卡片浮在纸上，有层次。
                .listRowBackground(DS.paperHi)
                        }
                    }

                    ForEach(entries) { entry in
                        JournalRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeSheet = .detail(entry)
                            }
                            .listRowBackground(DS.paperHi)
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadEntries()
                }
            }
        }
        .navigationTitle("Journal")
        .paperBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Export journal — Pro-only
                Button {
                    if subscriptionManager.isPro {
                        activeSheet = .export
                    } else {
                        subscriptionManager.openPaywall(.journalExport)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(AppState.tr("Export Journal"))
            }
        }
        // 单一 sheet（修 2026-09-10：原为两个 .sheet 挂同层 → 详情页空白）
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let entry):
                JournalEntryDetailView(entry: entry)
            case .export:
                ShareSheet(activityItems: [exportText])
            }
        }
        .task {
            await loadEntries()
        }
    }

    /// Build a plain-text export of the journal (Pro feature)
    private var exportText: String {
        var text = "☯ TaoMind Journal\n"
        text += "\(entries.count) entries\n"
        text += "──────────────\n\n"
        for (index, entry) in entries.enumerated() {
            text += "\(index + 1). \(entry.question)\n"
            text += "   \(entry.formattedDate)\n"
            if !entry.passage.isEmpty {
                text += "   📜 \(entry.passage)\n"
            }
            if !entry.wisdom.isEmpty {
                text += "   🌿 \(entry.wisdom)\n"
            }
            if !entry.reflection.isEmpty {
                text += "   🪞 \(entry.reflection)\n"
            }
            if !entry.way_forward.isEmpty {
                text += "   💧 \(entry.way_forward)\n"
            }
            text += "\n"
        }
        return text
    }

    private func loadEntries() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.listJournal()
            // 修 bug 2026-09-10：取消路径原来直接 return，isLoading 永远停在 true
            // → 页面永久停在「正在加载你的修行日志……」转圈，加载不出来。
            if Task.isCancelled {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run {
                entries = result
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run { isLoading = false }
        } catch let error as URLError where error.code == .cancelled {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        // For now, local deletion only (API delete endpoint not implemented)
        entries.remove(atOffsets: offsets)
    }
}

// MARK: - Journal Row

struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.question)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DS.ink)
                    .lineLimit(2)

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(DS.cinnabar)
                }
            }

            HStack(spacing: 8) {
                Label(entry.scenario_type.replacingOccurrences(of: "_", with: " ").capitalized,
                      systemImage: "tag")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(entry.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !entry.wisdom.isEmpty {
                Text(entry.wisdom)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
