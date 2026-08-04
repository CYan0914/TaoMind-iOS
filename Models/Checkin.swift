import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: Int
    let provider: String
    let provider_user_id: String
    let email: String
    let display_name: String
}

// MARK: - Auth Response

struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Daily Check-in (每日功课)

struct Checkin: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let checkin_date: String
    let source: String        // "verse" | "wisdom"
    let verse_text: String
    let reflection: String
    let master_feedback: String?
    let created_at: String
}

struct CheckinSaveResponse: Codable {
    let checkin: Checkin
    let streak: Streak
}

struct CheckinListResponse: Codable {
    let checkins: [Checkin]
    let today: Checkin?
    let streak: Streak
    let backfill: BackfillInfo?
}

// MARK: - Backfill (补卡)

struct BackfillInfo: Codable {
    let available: Bool
    let target_date: String?

    var targetDate: String? { target_date }
}

struct BackfillResponse: Codable {
    let checkin: Checkin
    let streak: Streak
}

// MARK: - Streak

struct Streak: Codable {
    let current_streak: Int
    let longest_streak: Int
    let today_done: Bool
    let total_checkins: Int
    let last_checkin_date: String?

    var currentStreak: Int { current_streak }
    var longestStreak: Int { longest_streak }
    var todayDone: Bool { today_done }
    var totalCheckins: Int { total_checkins }
}

// MARK: - Feedback

struct FeedbackResponse: Codable {
    let feedback: String
    let cached: Bool?
}

// MARK: - Master Follow-up Chat (名师追问)

struct MasterChatResponse: Codable {
    let reply: String
}

/// One message in the follow-up conversation with the master.
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String       // "user" | "master"
    let content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}
