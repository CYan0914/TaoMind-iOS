import SwiftUI

// MARK: - Daily Verse Card

struct DailyVerseCard: View {
    let verse: DailyVerse
    /// build 50: 个性化 verse 走"为你而选"eyebrow + 朱砂色,跟固定 verse 视觉区分
    var isPersonalized: Bool = false

    /// 只用来建立「语言变化 → 重绘」依赖。
    ///
    /// `localized*` 与 `AppState.tr` 读的都是静态 `AppState.currentLocaleId`，
    /// SwiftUI 观察不到它。base verse 本来就中英双列齐全，切语言不需要换数据，
    /// `verse` 值不变 → 本视图 body 不会重算 → 卡片一直停在旧语言。这正是
    /// 「英文系统切到中文，经文仍是英文」的最后一环。
    @EnvironmentObject private var appState: AppState

    // 双语列由 verse 的 localized* 访问器按当前语言选择（2026-09-30），
    // 这里不再直接读 verse_text / reflection。

    var body: some View {
        let _ = appState.language   // 建立重绘依赖，见上方注释
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
        // 展开态限宽：卡内全是居中长句（经文 + 感悟），铺满内屏宽会读成一条横线。
        // 限到 600 居中；窄屏可用宽本就不足 600，行为不变。
        .readableColumn(max: 600)
    }
}
