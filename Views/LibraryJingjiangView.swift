import SwiftUI

// MARK: - Library Section · 道德经精讲
//
// 81 章精讲列表,排序按 chapter.num 升序.前 3 章免费(JingjiangService.freeChapterCount),
// 后续走 .jingjiangLocked paywall.点 sheet 推 JingjiangDetailView.

struct LibraryJingjiangView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var jingjiang = JingjiangService.shared
    @State private var selectedChapter: JingjiangChapter?

    var body: some View {
        List {
            ForEach(jingjiang.chapters) { chapter in
                row(chapter)
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
        // 展开态限宽：每行只有「第 N 章 + 两行通释 + 锁标」，铺满 1000pt 宽会把
        // 通释行拉成极长单行。限到 640 居中，窄屏零变化。
        // ⚠️ 必须排在 `.paperBackground()` **之前** —— 纸色靠 ignoresSafeArea 铺满，
        // 若限宽在它外层，两侧会露出 TabView 的白底。
        .readableColumn(max: 640)
        .paperBackground()
        .navigationTitle(AppState.tr("library_jingjiang"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedChapter) { chapter in
            NavigationStack {
                JingjiangDetailView(chapter: chapter)
            }
        }
        // 原来这里有 100pt 透明 safeAreaInset「躲 tab bar」。已删：List 本身就在
        // tab bar 的安全区内，这层是重复补偿。iPhone Duo 展开后 tab bar 移到右缘，
        // 它会变成底部死白。
    }

    @MainActor
    private func row(_ chapter: JingjiangChapter) -> some View {
        let locked = jingjiang.isLocked(chapter, isPro: subscriptionManager.isPro)
        return Button {
            if locked {
                subscriptionManager.openPaywall(.jingjiangLocked)
                return
            }
            selectedChapter = chapter
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
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
