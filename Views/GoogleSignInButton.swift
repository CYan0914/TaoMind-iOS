import SwiftUI

// MARK: - Google Sign-In Button
// build 39: Reusable Google sign-in button that follows Apple Sign-In's
// visual weight (52pt height, full width, border) but uses Google's brand
// colors on the "G" mark. The white-on-paper contrast is intentional so
// the button is visually distinct from the black Apple button.

struct GoogleSignInButton: View {
    let action: () -> Void
    let isLoading: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google brand G — four-color ring
                GoogleGLogo()
                    .frame(width: 20, height: 20)
                Text(AppState.tr("Continue with Google"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DS.indigo, lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

/// Approximation of the Google "G" mark using 4 brand-colored arcs.
private struct GoogleGLogo: View {
    var body: some View {
        ZStack {
            // White base so the G reads cleanly over any background
            Circle()
                .fill(Color.white)
            // Multicolor ring using quarter-arcs
            Circle()
                .trim(from: 0.00, to: 0.25)
                .stroke(Color(red: 0.918, green: 0.263, blue: 0.208), lineWidth: 2.5) // red
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.25, to: 0.50)
                .stroke(Color(red: 0.984, green: 0.737, blue: 0.020), lineWidth: 2.5) // yellow
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.50, to: 0.75)
                .stroke(Color(red: 0.204, green: 0.659, blue: 0.325), lineWidth: 2.5) // green
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.75, to: 1.00)
                .stroke(Color(red: 0.259, green: 0.522, blue: 0.957), lineWidth: 2.5) // blue
                .rotationEffect(.degrees(-90))
            // The crossbar of the G (Google G has a horizontal bar on the right)
            Rectangle()
                .fill(Color(red: 0.259, green: 0.522, blue: 0.957))
                .frame(width: 9, height: 2.5)
                .offset(x: 3, y: 0)
        }
    }
}
