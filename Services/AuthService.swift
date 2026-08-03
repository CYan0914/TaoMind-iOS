import Foundation
import AuthenticationServices

// MARK: - Auth Service (Sign in with Apple)

@MainActor
final class AuthService: NSObject, ObservableObject {

    static let shared = AuthService()

    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published var isAuthenticating = false

    private let userKey = "authUser"
    private let tokenKey = "authToken"

    override private init() {
        super.init()
        // Restore session from previous launch
        if let data = UserDefaults.standard.data(forKey: userKey),
           let savedUser = try? JSONDecoder().decode(User.self, from: data),
           let savedToken = UserDefaults.standard.string(forKey: tokenKey) {
            self.user = savedUser
            self.token = savedToken
        }
    }

    var isSignedIn: Bool { token != nil && user != nil }

    /// Authorization header for authenticated API calls
    var authHeaders: [String: String] {
        ["Authorization": "Bearer \(token ?? "")"]
    }

    // MARK: - Sign In

    /// Complete a Sign in with Apple result: extract the identity token and
    /// exchange it with the backend for a TaoMind session.
    func handleSignIn(_ result: Result<ASAuthorization, Error>) async -> Bool {
        switch result {
        case .failure(let error):
            print("[Auth] Sign in failed: \(error)")
            return false
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                print("[Auth] No identity token from Apple")
                return false
            }

            let email = credential.email ?? ""
            let name: String
            if let fullName = credential.fullName {
                name = [fullName.givenName, fullName.familyName].compactMap { $0 }.joined(separator: " ")
            } else {
                name = ""
            }

            isAuthenticating = true
            defer { isAuthenticating = false }

            return await exchange(identityToken: identityToken, email: email, displayName: name)
        }
    }

    private func exchange(identityToken: String, email: String, displayName: String) async -> Bool {
        let url = URL(string: "\(apiBaseURL)/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "identity_token": identityToken,
            "email": email,
            "display_name": displayName,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[Auth] Backend rejected: \(response)")
                return false
            }
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.user = auth.user
            self.token = auth.token
            persist()
            print("[Auth] Signed in as user \(auth.user.id) ✅")
            return true
        } catch {
            print("[Auth] Network error: \(error)")
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        user = nil
        token = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
}
