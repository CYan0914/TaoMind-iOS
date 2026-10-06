import SwiftUI

// MARK: - Daily Verse Card

struct DailyVerseCard: View {
    let verse: DailyVerse
    /// build 50: 个性化 verse 走"为你而选"eyebrow + 朱砂色,跟固定 verse 视觉区分
    var isPersonalized: Bool = false

    // 双语列由 verse 的 localized* 访问器按当前语言选择（2026-09-30），
    // 这里不再直接读 verse_text / reflection。

    var body: some View {
        VStack(spacing: 12) {
            Text(AppState.tr(isPersonalized ? "personalized_verse_eyebrow" : "daily_verse_eyebrow"))
                .eyebrowStyle(isPersonalized ? DS.cinnabar : DS.bronze)

            Text(verse.localizedVerse)
                .font(DS.verse(16, relativeTo: .body))
                .foregroundColor(DS.ink)
                .lineSpacing(6)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("—")
                    .foregroundColor(DS.inkFaint)
                Text(verse.source)
                    .fontWeight(.semibold)
                if !verse.localizedChapter.isEmpty {
                    Text("· \(verse.localizedChapter)")
                }
            }
            .font(.caption)
            .foregroundColor(DS.inkSoft)

            Text(verse.localizedReflection)
                .font(DS.verse(14, relativeTo: .footnote))
                .foregroundColor(DS.inkSoft)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.ink.opacity(0.04))
                )
        }
        .padding(20)
        .paperCard()
    }
}
