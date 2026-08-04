import Foundation

// MARK: - Check-in API Client (每日功课)

@MainActor
struct CheckinService {
    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

    // MARK: - Save today's check-in

    func saveCheckin(source: String, verseText: String, reflection: String) async throws -> CheckinSaveResponse {
        var request = makeRequest(path: "/checkin", method: "POST")
        let body: [String: Any] = [
            "source": source,
            "verse_text": verseText,
            "reflection": reflection,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    // MARK: - Fetch check-ins + today's status + streak

    func fetchStatus() async throws -> CheckinListResponse {
        let request = makeRequest(path: "/checkin", method: "GET")
        return try await perform(request)
    }

    // MARK: - Master feedback (名师指点, Pro)

    func requestFeedback(checkinId: Int, language: String) async throws -> FeedbackResponse {
        var request = makeRequest(path: "/checkin/feedback", method: "POST")
        let body: [String: Any] = [
            "checkin_id": checkinId,
            "language": language,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    // MARK: - Master follow-up chat (名师追问, Pro)

    func sendMasterChat(checkinId: Int, message: String, history: [ChatMessage], language: String) async throws -> MasterChatResponse {
        var request = makeRequest(path: "/checkin/\(checkinId)/chat", method: "POST")
        let body: [String: Any] = [
            "message": message,
            "history": history.map { ["role": $0.role, "content": $0.content] },
            "language": language,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String) -> URLRequest {
        let url = URL(string: "\(apiBaseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        // Attach auth headers from the current session
        for (key, value) in AuthService.shared.authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw APIError.serverError("Session expired")
            }
            throw APIError.serverError("Server error: \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
