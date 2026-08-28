import Foundation

// MARK: - API Client

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        case .serverError(let m): return m
        case .noData: return "No response from server"
        }
    }
}

class APIClient {
    let baseURL: String
    let session: URLSession
    let decoder: JSONDecoder

    init(baseURL: String = "https://taomindapp.com") {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        let url = try makeURL("/health")
        let (_, response) = try await session.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Referral (推荐裂变)

    /// GET /referral/my-code —— 取或生成当前用户的 8 位邀请码
    func getMyReferralCode(authToken: String) async throws -> ReferralCodeResp {
        let url = try makeURL("/referral/my-code")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(ReferralCodeResp.self, from: data)
    }

    /// GET /referral/status —— 当前用户作为 inviter 的邀请概况
    func getReferralStatus(authToken: String) async throws -> ReferralStatus {
        let url = try makeURL("/referral/status")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(ReferralStatus.self, from: data)
    }

    /// POST /referral/redeem —— 用 8 位码换双方各 7 天 Pro
    func redeemReferral(code: String, authToken: String) async throws -> ReferralRedeemResp {
        let url = try makeURL("/referral/redeem")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        let body = ["code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(ReferralRedeemResp.self, from: data)
    }

    // MARK: - Daily Verse

    func getDailyVerse() async throws -> DailyVerse {
        let url = try makeURL("/daily-verse")
        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(DailyVerse.self, from: data)
    }

    // MARK: - Seek Wisdom

    func seekWisdom(
        question: String,
        scenarioType: String = "business_decision",
        temperature: Double = 0.7,
        language: String = "en",
        authToken: String? = nil
    ) async throws -> WisdomResponse {
        let url = try makeURL("/seek-wisdom")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        // 登录用户带上 session token → 后端按用户级限额（免费 3/天，Pro 50/天）而非匿名单 IP 上限
        if let authToken = authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "question": question,
            "scenario_type": scenarioType,
            "temperature": temperature,
            "language": language
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(WisdomResponse.self, from: data)
    }

    // MARK: - Library

    func fetchLibrary() async throws -> LibraryResponse {
        let url = try makeURL("/library")
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        // 带登录态 → 服务端按 Pro 下发完整精讲（免费用户仅前 5 章，服务端 gate）
        attachAuth(&request)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(LibraryResponse.self, from: data)
    }

    // MARK: - Journal

    func saveJournal(
        question: String,
        scenarioType: String,
        passage: String,
        wisdom: String,
        reflection: String,
        wayForward: String
    ) async throws -> Int {
        let url = try makeURL("/journal")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 带登录态 → 服务端按用户归户存储并执行免费 20 条上限
        attachAuth(&request)

        let body: [String: Any] = [
            "question": question,
            "scenario_type": scenarioType,
            "passage": passage,
            "wisdom": wisdom,
            "reflection": reflection,
            "way_forward": wayForward,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validate(response)

        struct SaveResult: Codable {
            let id: Int
        }
        let result = try decoder.decode(SaveResult.self, from: data)
        return result.id
    }

    func listJournal(limit: Int = 50) async throws -> [JournalEntry] {
        let url = try makeURL("/journal", params: ["limit": "\(limit)"])
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        // 带登录态 → 服务端只返回本人日志（含历史公共条目，逐步收敛归户）
        attachAuth(&request)
        let (data, response) = try await session.data(for: request)
        try validate(response)

        struct JournalResponse: Codable {
            let entries: [JournalEntry]
            let total: Int
        }
        let result = try decoder.decode(JournalResponse.self, from: data)
        return result.entries
    }

    // MARK: - Analytics

    /// 埋点上报（fire-and-forget，调用方用 try? 吞错）。只传事件名与非内容属性。
    func trackEvent(event: String, properties: [String: String]) async throws {
        let url = try makeURL("/analytics/track")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        attachAuth(&request)
        var body: [String: Any] = ["event": event]
        if let propsData = try? JSONSerialization.data(withJSONObject: properties),
           let propsJSON = String(data: propsData, encoding: .utf8) {
            body["properties"] = propsJSON
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        _ = data
    }

    // MARK: - Helpers

    /// 登录态注入：有 session token 就带 Bearer header（服务端据此归户/校验权益）。
    /// token 从 UserDefaults 读（AuthService.persist/signOut 同步维护，线程安全）——
    /// AuthService 是 @MainActor，这里可能在任意 executor 上被调，不能直接引用其隔离属性。
    private func attachAuth(_ request: inout URLRequest) {
        let token = UserDefaults.standard.string(forKey: "authToken")
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func makeURL(_ path: String, params: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
}
