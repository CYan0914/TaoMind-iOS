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
