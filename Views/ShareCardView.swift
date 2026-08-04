import SwiftUI
import UIKit

// MARK: - Share Card (分享卡片)

/// Content for a shareable TaoMind card (streak / milestone / reflection).
struct ShareCardContent: Identifiable {
    let id = UUID()
    var title: String       // e.g. "连续打卡 21 天"
    var verse: String       // 经文或引语
    var note: String        // 感悟摘录（可空）
    var subtitle: String    // 底部署名，如 "TaoMind · 每日功课"
}

/// Reusable TaoMind share-card view — rendered to an image via ImageRenderer.
struct ShareCardView: View {
    let content: ShareCardContent

    var body: some View {
        VStack(spacing: 18) {
            Text("☯")
                .font(.system(size: 44))

            Text(content.title)
                .font(.custom("Georgia", size: 26, relativeTo: .title))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                .multilineTextAlignment(.center)

            if !content.verse.isEmpty {
                Rectangle()
                    .fill(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.25))
                    .frame(width: 44, height: 1)
                Text(content.verse)
                    .font(.custom("Georgia", size: 16, relativeTo: .body))
                    .italic()
                    .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            if !content.note.isEmpty {
                Text(content.note)
                    .font(.custom("Georgia", size: 14, relativeTo: .caption))
                    .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16).opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer(minLength: 4)

            Text(content.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 340, height: 440)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Share Card Preview Sheet

/// Presents the card with a share button that renders it to an image.
struct ShareCardPreviewSheet: View {
    let content: ShareCardContent
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 20) {
            ShareCardView(content: content)
            Button(action: { showShareSheet = true }) {
                Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.17, green: 0.14, blue: 0.09))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding(.top, 24)
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showShareSheet) {
            if let img = ShareCardRenderer.image(for: content) {
                ShareSheet(activityItems: [img])
            }
        }
    }
}

// MARK: - Share Card Renderer

enum ShareCardRenderer {
    /// Render a ShareCardView to a UIImage for the share sheet (iOS 16+).
    static func image(for content: ShareCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
