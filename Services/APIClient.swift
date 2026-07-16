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

    init(baseURL: String = "https://observant-prosperity-production-92d3.up.railway.app") {
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
        language: String = "en"
    ) async throws -> WisdomResponse {
        let url = try makeURL("/seek-wisdom")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

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
        let (data, response) = try await session.data(from: url)
        try validate(response)

        struct JournalResponse: Codable {
            let entries: [JournalEntry]
            let total: Int
        }
        let result = try decoder.decode(JournalResponse.self, from: data)
        return result.entries
    }

    // MARK: - Helpers

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
