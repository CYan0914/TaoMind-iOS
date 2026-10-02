import Foundation

// MARK: - Daily Verse Model

struct DailyVerse: Codable, Identifiable {
    let id = UUID()
    let source: String
    let chapter: String
    let verse_text: String
    let reflection: String
    /// 双语列（后端 /daily-verse 2026-09-30 起返回）。老缓存 / 老后端可能为空。
    ///
    /// 用 `var` + 默认值而非 `let`：`PersonalizedDailyVerse` 会把这个结构体
    /// 编进 UserDefaults 缓存，升级后解旧缓存时缺这三个 key 会解码失败
    /// （`try?` 静默返回 nil → 用户当天的个性化经文丢失）。
    var chapter_en: String? = nil
    var verse_text_en: String? = nil
    var reflection_en: String? = nil

    enum CodingKeys: String, CodingKey {
        case source, chapter, verse_text, reflection
        case chapter_en, verse_text_en, reflection_en
    }

    /// 按当前界面语言选字段，**两个方向都回落**（哪一槽为空就取另一槽）。
    ///
    /// 老版本中文分支是裸 `return zh`，不检查空：个性化 verse 在英文模式下
    /// 只写 `_en` 三列、主字段留空（见 PersonalizedDailyVerseService.bilingual），
    /// 用户从英文切回中文时 `Text("")` → 整张卡空白（1.8.0 线上 bug）。
    /// 回落成英文总好过空白。
    /// 与 `LibraryEntry.localized(zh:en:)` 同一套语义。
    @MainActor private func localized(_ zh: String, _ en: String?) -> String {
        let e = en ?? ""
        if AppState.currentLocaleId == "zh-Hans" { return zh.isEmpty ? e : zh }
        return e.isEmpty ? zh : e
    }

    @MainActor var localizedChapter: String { localized(chapter, chapter_en) }
    @MainActor var localizedVerse: String { localized(verse_text, verse_text_en) }
    @MainActor var localizedReflection: String { localized(reflection, reflection_en) }
}

// MARK: - Personalized Daily Verse (build 50: 情绪化每日经文)
//
// `DailyVerse` 本体保持字节级兼容(老 codepath 用得到 source/chapter/verse_text/reflection)。
// 个性化缓存用这个 envelope 包装：记录生成时刻 + 当日 mood + userIntent,
// 方便后续做"为什么选这章"的可观测性(analytics)与去重。
//
// 注意：`verse` 的 `id` 是 `let id = UUID()` —— 跨日 cache miss 时
// SwiftUI 不会因为 id 相同而误判是同一条。

/// 1.8.1 起：一天一条「日期实体」，两个语言槽住在实体内部。
///
/// 老结构只有单个 `verse`（且缓存 key 带 language 后缀）→ 切语言必然 cache miss
/// → 重选一次经。现在 key 去掉 language，中英两份挂在同一个实体上，切语言通常
/// 只是换槽位读，不发网络请求，章节也就固定住了。
///
/// 兼容性：两个新字段都是 Optional。Swift 合成 Codable 对 Optional 属性走
/// `decodeIfPresent`，老缓存缺这两个 key 不会解码失败；老数据里 `verse` 存的
/// 正是「中文那次」的产出，所以直接当中文槽用（英文槽为空 → 首切英文才补一次）。
struct PersonalizedDailyVerse: Codable {
    /// 中文槽。老缓存解码出来直接落这里。
    var verse: DailyVerse? = nil
    /// 英文槽（1.8.1 新增）。
    var en: DailyVerse? = nil
    let generatedAt: Date
    /// 原为 `let`；补槽时会更新，改成 `var`（老缓存解码不受影响）。
    var moodRaw: String?
    var userIntent: String?

    /// 把新生成的一份文案落进目标语言槽，另一槽原样不动。
    func writing(_ v: DailyVerse, isEnglish: Bool) -> PersonalizedDailyVerse {
        var updated = self
        if isEnglish { updated.en = v } else { updated.verse = v }
        return updated
    }
}

// MARK: - Wisdom Response Model

struct WisdomResponse: Codable, Identifiable {
    let id = UUID()
    let passage: String
    let wisdom: String
    let reflection: String
    let way_forward: String

    enum CodingKeys: String, CodingKey {
        case passage, wisdom, reflection, way_forward
    }
}

// MARK: - Journal Entry Model

struct JournalEntry: Codable, Identifiable {
    let id: Int
    let question: String
    let scenario_type: String
    let passage: String
    let wisdom: String
    let reflection: String
    let way_forward: String
    let notes: String?
    let is_favorite: Int
    let created_at: String

    var isFavorite: Bool { is_favorite == 1 }
    var formattedDate: String {
        // Parse ISO date from API
        guard let date = ISO8601DateFormatter().date(from: created_at) ??
              DateFormatter.apiDate.date(from: String(created_at.prefix(19)))
        else { return created_at }
        return DateFormatter.prettyDate.string(from: date)
    }
}

// MARK: - Scenario Types

enum ScenarioType: String, CaseIterable, Identifiable {
    case business_decision = "Business Decision"
    case leadership = "Leadership"
    case career = "Career"
    case personal = "Personal"
    case conflict = "Conflict"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .business_decision: return "briefcase"
        case .leadership: return "person.3"
        case .career: return "arrow.up.right"
        case .personal: return "heart"
        case .conflict: return "exclamationmark.triangle"
        }
    }

    var apiValue: String {
        switch self {
        case .business_decision: return "business_decision"
        case .leadership: return "leadership"
        case .career: return "career"
        case .personal: return "personal"
        case .conflict: return "conflict"
        }
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let prettyDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
