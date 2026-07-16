import SwiftUI

// MARK: - Wisdom Result View

struct WisdomResultView: View {
    let result: WisdomResponse
    let question: String
    let scenarioType: ScenarioType

    @State private var isFavorite = false
    @State private var showShareSheet = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 24) {
            // Divider
            HStack {
                VStack { Divider().frame(height: 1).background(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.3)) }
                Text("The Sage Speaks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                VStack { Divider().frame(height: 1).background(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.3)) }
            }

            // Passage
            WisdomSection(
                icon: "📜",
                title: "The Passage",
                content: result.passage
            )

            // Wisdom
            WisdomSection(
                icon: "🌿",
                title: "The Wisdom",
                content: result.wisdom
            )

            // Reflection
            WisdomSection(
                icon: "🪞",
                title: "The Reflection",
                content: result.reflection
            )

            // Way Forward
            WisdomSection(
                icon: "💧",
                title: "The Way Forward",
                content: result.way_forward
            )

            // MARK: - Action Buttons
            HStack(spacing: 16) {
                // Share
                Button(action: { showShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Copy
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Favorite
                Button(action: { withAnimation { isFavorite.toggle() } }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorite ? .red : .secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
            .padding(.top, 8)

            // Copied toast
            if showCopiedToast {
                Text("Copied to clipboard ✨")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }

    private var shareText: String {
        """
        ☯ TaoMind Wisdom

        📜 \(result.passage)

        🌿 \(result.wisdom)

        🪞 \(result.reflection)

        💧 \(result.way_forward)

        — from TaoMind
        """
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = shareText
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Wisdom Section

struct WisdomSection: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.title3)
                Text(title)
                    .font(.custom("Georgia", size: 16, relativeTo: .headline))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
            }

            Text(content)
                .font(.custom("Georgia", size: 15, relativeTo: .body))
                .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.7))
                .cornerRadius(12)
        }
    }
}

// MARK: - Share Sheet (UIKit bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
