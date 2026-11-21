import SwiftUI

// MARK: - Daily Verse Card

struct DailyVerseCard: View {
    let verse: DailyVerse
    /// build 50: 个性化 verse 走"为你而选"eyebrow + 朱砂色,跟固定 verse 视觉区分
    var isPersonalized: Bool = false

    /// 纯版面模式：不加卡片边框，直接把经文排在纸面上。
    ///
    /// Practice 页原来是一列等宽卡片（连击头 / 体验卡进度 / 经文 / 输入框 /
    /// 各入口），每张卡同底色同圆角，等于把"今天该读什么"降级成第 N 张卡。
    /// 打开纯版面模式后，经文成为纸面上的正文，其余才是工具卡，主次一眼分开。
    var plain: Bool = false

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
        Group {
            if plain {
                content
                    .padding(.vertical, 22)
                    .overlay(alignment: .top) { hairline }
                    .overlay(alignment: .bottom) { hairline }
            } else {
                content
                    .padding(20)
                    .paperCard()
            }
        }
        // 展开态限宽：卡内全是居中长句（经文 + 感悟），铺满内屏宽会读成一条横线。
        // 限到 600 居中；窄屏可用宽本就不足 600，行为不变。
        .readableColumn(max: 600)
    }

    private var content: some View {
        VStack(spacing: 12) {
            Text(AppState.tr(isPersonalized ? "personalized_verse_eyebrow" : "daily_verse_eyebrow"))
                .eyebrowStyle(isPersonalized ? DS.cinnabar : DS.bronzeDeep)

            Text(verse.localizedVerse)
                .font(DS.verse(plain ? 18 : 16, relativeTo: .body))
                .foregroundColor(DS.ink)
                .lineSpacing(plain ? 8 : 6)
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
                        .fill(DS.ink.opacity(plain ? 0.03 : 0.04))
                )
        }
    }

    /// 纯版面模式下的上下细线：给正文一个"书页"的边界，而不是靠卡片阴影。
    private var hairline: some View {
        Rectangle()
            .fill(DS.ink.opacity(0.12))
            .frame(height: 0.5)
    }
}
