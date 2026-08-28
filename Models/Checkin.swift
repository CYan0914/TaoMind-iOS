import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: Int
    let provider: String
    let provider_user_id: String
    let email: String
    let display_name: String
    // 后端 2026-08 build 34 新增：用户自己的 8 位邀请码（/auth/apple 响应注入）
    let referral_code: String?
    // snake_case 字段配套的 camelCase 访问器（避免全项目替换风险）
    var displayName: String { display_name }
    var referralCode: String? { referral_code }

    // 兼容老后端（user 表无 referral_code 字段时也不挂）
    enum CodingKeys: String, CodingKey {
        case id, provider, provider_user_id, email, display_name, referral_code
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.provider = try c.decode(String.self, forKey: .provider)
        self.provider_user_id = try c.decode(String.self, forKey: .provider_user_id)
        self.email = try c.decode(String.self, forKey: .email)
        self.display_name = try c.decode(String.self, forKey: .display_name)
        self.referral_code = try c.decodeIfPresent(String.self, forKey: .referral_code)
    }
}

// MARK: - Auth Response

struct AuthResponse: Codable {
    let token: String
    let user: User
    // 后端在 token 与 user 之外也单独返回 referral_code（双轨，老客户端忽略即可）
    let referral_code: String?
    var referralCode: String? { referral_code }

    // 自定义 decode 容忍老后端（build 34 之前）响应里没有 referral_code 字段——
    // 否则新客户端 → 老后端会解码失败导致登录挂掉
    enum CodingKeys: String, CodingKey {
        case token, user, referral_code
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
        self.user = try c.decode(User.self, forKey: .user)
        self.referral_code = try c.decodeIfPresent(String.self, forKey: .referral_code)
    }
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

// MARK: - Monthly Report (月报)

struct MonthlyReportResponse: Codable {
    let month: String
    let report: String
    let count: Int
}

// MARK: - Library (经藏)

struct LibraryEntry: Codable, Identifiable {
    let source: String
    let chapter: String
    let verse_text: String
    let commentary: String
    let reflection: String
    let display_order: Int

    var id: Int { display_order }
}

struct LibraryResponse: Codable {
    let entries: [LibraryEntry]
    let total: Int
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
    var lastCheckinDate: String? { last_checkin_date }
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

// MARK: - Entitlement Sync (权益上报, W1)

struct EntitlementSyncResponse: Codable {
    let ok: Bool
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

// MARK: - Referral (推荐裂变)

struct ReferralCodeResp: Codable {
    let code: String
    let share_url: String
    let redeemed_by_user_id: Int?
    let redeemed_at: String?
    var shareURL: String { share_url }
    var redeemedByUserId: Int? { redeemed_by_user_id }
    var redeemedAt: String? { redeemed_at }
}

struct ReferralStatus: Codable {
    let code: String?
    let has_invited: Bool
    let invite_count: Int
    let total_granted_days: Int
    let redeemed_by_user_id: Int?
    let redeemed_at: String?
    var hasInvited: Bool { has_invited }
    var inviteCount: Int { invite_count }
    var totalGrantedDays: Int { total_granted_days }
    var redeemedByUserId: Int? { redeemed_by_user_id }
    var redeemedAt: String? { redeemed_at }
}

struct ReferralRedeemResp: Codable {
    let ok: Bool
    let granted_days: Int
    let inviter_user_id: Int
    let new_pro_until: String?
    var grantedDays: Int { granted_days }
    var inviterUserId: Int { inviter_user_id }
    var newProUntil: String? { new_pro_until }
}
