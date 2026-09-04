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
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LibraryDetailView(entry: entry)
            }
        }
        // 修设计审计 2026-09-02 Blocker 2：List 底部加 100pt 透明 inset，
        // 让最后一章不被 iOS tab bar 切。
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
    }

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
