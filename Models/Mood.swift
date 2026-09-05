import Foundation

// MARK: - Mood (每日经文 · 用户状态, build 50)
//
// 4 个 case 覆盖 valence × arousal 二维 2×2 象限：
//   - calm     (high valence, low arousal)  平静 → 配「静」
//   - restless (low valence, high arousal) 烦躁 → 配「水」
//   - stuck    (low valence, low arousal)  卡住 → 配「无为」
//   - hopeful  (high valence, high arousal) 期待 → 配「初发」
//
// 不绑生活领域（career/personal/conflict），那个维度由 onboarding 的 userIntent 覆盖。
// 这里只表达"今天状态"，让 LLM 选 1 章最合当下的经文。

enum Mood: String, Codable, CaseIterable, Identifiable {
    case calm
    case restless
    case stuck
    case hopeful

    var id: String { rawValue }

    /// SF Symbol + 标签 chip 上显示的 emoji
    var emoji: String {
        switch self {
        case .calm: return "🌿"
        case .restless: return "💧"
        case .stuck: return "🪨"
        case .hopeful: return "🌅"
        }
    }

    /// 走 AppState.tr() 的 i18n key
    var displayKey: String { "mood_\(rawValue)" }

    /// 喂给 LLM 的 prompt 值
    var apiValue: String { rawValue }
}
