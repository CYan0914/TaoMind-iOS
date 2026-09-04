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
        .paperBackground()
        .navigationTitle(AppState.tr("library_jingjiang"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedChapter) { chapter in
            NavigationStack {
                JingjiangDetailView(chapter: chapter)
            }
        }
        // 修设计审计 2026-09-02 Blocker 2：List 底部加 100pt 透明 inset，
        // 让最后一章不被 iOS tab bar 切。
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
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
