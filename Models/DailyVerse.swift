import Foundation

// MARK: - Daily Verse Model

struct DailyVerse: Codable, Identifiable {
    let id = UUID()
    let source: String
    let chapter: String
    let verse_text: String
    let reflection: String

    enum CodingKeys: String, CodingKey {
        case source, chapter, verse_text, reflection
    }
}

// MARK: - Personalized Daily Verse (build 50: 情绪化每日经文)
//
// `DailyVerse` 本体保持字节级兼容(老 codepath 用得到 source/chapter/verse_text/reflection)。
// 个性化缓存用这个 envelope 包装：记录生成时刻 + 当日 mood + userIntent,
// 方便后续做"为什么选这章"的可观测性(analytics)与去重。
//
// 注意：`verse` 的 `id` 是 `let id = UUID()` —— 跨日 cache miss 时
// SwiftUI 不会因为 id 相同而误判是同一条。

struct PersonalizedDailyVerse: Codable {
    let verse: DailyVerse
    let generatedAt: Date
    let moodRaw: String?
    let userIntent: String?
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
