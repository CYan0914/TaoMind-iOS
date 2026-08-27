import SwiftUI
import UIKit
import CoreImage

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
/// 卡内自带 App Store 二维码：分享出去的纯图片也能带回下载（裂变闭环）。
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

            // 署名 + 下载引导（二维码必须画进图里 —— ImageRenderer 只导出位图）
            HStack(spacing: 12) {
                if let qr = QRCodeMaker.appStoreQR() {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 54, height: 54)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.subtitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    Text(AppState.tr("share_card_download_hint"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(28)
        .frame(width: 340, height: 480)
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

@MainActor
enum ShareCardRenderer {
    /// Render a ShareCardView to a UIImage for the share sheet (iOS 16+).
    static func image(for content: ShareCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
