import Foundation
import AuthenticationServices
import GoogleSignIn
import UIKit

// MARK: - Auth Service
// Supports Sign in with Apple (build 30+) and Google Sign-In (build 39+).
// Both providers share the same backend exchange flow at /auth/{provider}.

@MainActor
final class AuthService: NSObject, ObservableObject {

    static let shared = AuthService()

    private let apiBaseURL = "https://taomindapp.com"

    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published var isAuthenticating = false
    @Published var authError: String?

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

    // MARK: - Sign in with Apple (existing path)

    /// Complete a Sign in with Apple result: extract the identity token and
    /// exchange it with the backend for a TaoMind session.
    func handleSignIn(_ result: Result<ASAuthorization, Error>) async -> Bool {
        authError = nil
        switch result {
        case .failure(let error):
            print("[Auth] Apple sign in failed: \(error)")
            authError = "Sign in failed: \(error.localizedDescription)"
            return false
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("[Auth] Unexpected credential type: \(type(of: authorization.credential))")
                authError = "Unexpected Apple credential"
                return false
            }
            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                print("[Auth] No identity token from Apple")
                authError = "Could not obtain an Apple identity token"
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
            return await exchangeToken(
                provider: "apple",
                idToken: identityToken,
                email: email,
                displayName: name
            )
        }
    }

    // MARK: - Sign in with Google (build 39+)

    /// Trigger Google Sign-In flow. Presents the native Google account picker
    /// and exchanges the resulting ID token with the backend.
    func signInWithGoogle() async -> Bool {
        authError = nil

        // Restore last signed-in Google account silently (no UI).
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let error = error {
                print("[Auth] Google restorePreviousSignIn: \(error.localizedDescription)")
                return
            }
            guard let user = user else { return }
            Task { @MainActor in
                guard let self = self,
                      let idToken = user.idToken?.tokenString else { return }
                let email = user.profile?.email ?? ""
                let name = user.profile?.name ?? ""
                self.isAuthenticating = true
                defer { self.isAuthenticating = false }
                _ = await self.exchangeToken(
                    provider: "google",
                    idToken: idToken,
                    email: email,
                    displayName: name
                )
            }
        }

        guard let rootVC = Self.topViewController() else {
            authError = "No view controller available for sign-in"
            return false
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                authError = "Could not obtain a Google identity token"
                return false
            }
            let email = result.user.profile?.email ?? ""
            let name = result.user.profile?.name ?? ""

            isAuthenticating = true
            defer { isAuthenticating = false }
            return await exchangeToken(
                provider: "google",
                idToken: idToken,
                email: email,
                displayName: name
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            // User cancellation is not an error worth surfacing.
            print("[Auth] Google sign in cancelled by user")
            return false
        } catch {
            print("[Auth] Google sign in failed: \(error)")
            authError = "Google sign in failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Shared backend exchange

    /// Exchange an OAuth ID token (Apple or Google) with the backend for a
    /// TaoMind session. The backend handles user lookup/creation by
    /// `(provider, provider_user_id)`. The iOS side does not need to know
    /// the OAuth sub — the backend verifies the token and returns its own user.
    private func exchangeToken(
        provider: String,
        idToken: String,
        email: String,
        displayName: String
    ) async -> Bool {
        let url = URL(string: "\(apiBaseURL)/auth/\(provider)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "identity_token": idToken,
            "email": email,
            "display_name": displayName,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let detail = String(data: data, encoding: .utf8) ?? ""
                print("[Auth] Backend rejected: HTTP \(code) \(detail)")
                authError = "Server rejected sign-in (HTTP \(code))"
                return false
            }
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.user = auth.user
            self.token = auth.token
            persist()
            print("[Auth] Signed in as user \(auth.user.id) via \(auth.user.provider) ✅")
            return true
        } catch {
            print("[Auth] Network error: \(error)")
            authError = "Network error: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        // If the user signed in with Google, also sign out of Google to avoid
        // a stale account being restored on next launch.
        if user?.provider == "google" {
            GIDSignIn.sharedInstance.signOut()
        }
        user = nil
        token = nil
        authError = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    /// Force sign-out when the backend rejects the session (401). Keeps the
    /// message so the login screen can explain why re-auth is needed.
    func forceSignOut(message: String?) {
        user = nil
        token = nil
        authError = message
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    // MARK: - Helpers

    /// Find the topmost presented view controller for presenting modal sheets
    /// (Google Sign-In picker, Apple Sign-In sheet).
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var top = window.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
