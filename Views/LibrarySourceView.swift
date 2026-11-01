import SwiftUI

// MARK: - Library Section · 原文 (道德经 / 金刚经)
//
// 按 source 筛 + 按 display_order 升序排序,点 sheet 推 LibraryDetailView.
// 前 5 章免费(由 freeTasteCount 控制),后续走 .libraryLocked paywall.

struct LibrarySourceView: View {
    let title: String
    let source: String
    let entries: [LibraryEntry]

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedEntry: LibraryEntry?

    /// Free tier can read the first 5 chapters of each source as a taste.
    private let freeTasteCount = 5

    var body: some View {
        List {
            ForEach(entries) { entry in
                row(entry)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 修 UI 一致性 2026-09-10（v3，前两版都错）：
        // ⚠️ listRowBackground 是**行级**修饰符 —— 加在 List 上是 no-op（v1 错这里）。
        // ⚠️ v2 用了 DS.paper（= 页面底色）→ 行与背景完全同色，卡片"消失"，比白色更糟。
        // ✅ 正解 DS.paperHi（卡纸色 #FDFBF5，比页面底 #F4EFE3 略亮），与「功课」页的
        //    心情 chip（MoodChipRow）、经藏入口卡、珍藏卡一致 —— 卡片浮在纸上，有层次。
        .listRowBackground(DS.paperHi)
        // 展开态限宽：行内容只有「章名 + 两行经文 + 锁标」，铺满内屏宽会把经文拉成长单行。
        // ⚠️ 必须排在 `.paperBackground()` **之前** —— 纸色靠 ignoresSafeArea 铺满，
        // 若限宽在它外层，两侧会露出 TabView 的白底。
        .readableColumn(max: 640)
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LibraryDetailView(entry: entry)
            }
        }
        // 原来这里有 100pt 透明 safeAreaInset「躲 tab bar」。已删：List 本身就在
        // tab bar 的安全区内，这层是重复补偿。iPhone Duo 展开后 tab bar 移到右缘，
        // 它会变成底部死白。
    }

    @MainActor
    private func row(_ entry: LibraryEntry) -> some View {
        let locked = isLocked(entry)
        return Button {
            if locked {
                subscriptionManager.openPaywall(.libraryLocked)
                return
            }
            selectedEntry = entry
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.localizedChapter)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.ink)
                    Text(entry.localizedVerse)
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
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func isLocked(_ entry: LibraryEntry) -> Bool {
        guard !subscriptionManager.isPro else { return false }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        return index >= freeTasteCount
    }
}
