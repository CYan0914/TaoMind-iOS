import SwiftUI
import AuthenticationServices

// MARK: - Sign In (Sign in with Apple)

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("☯")
                .font(.system(size: 56))
            Text("Sign in to Practice")
                .font(.custom("Georgia", size: 22, relativeTo: .title2))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
            Text("Your daily practice and streaks sync across devices.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task {
                        let ok = await authService.handleSignIn(result)
                        if ok {
                            dismiss()
                        }
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 32)
            .disabled(authService.isAuthenticating)

            if authService.isAuthenticating {
                ProgressView()
                    .padding(.top, 8)
            }

            if let err = authService.authError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.vertical, 20)
    }
}
