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
    var attribution: String?  // 社交裂变署名（build 34 新增），如 "shared by @zhanghaojia_91 on day 7"
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
                .foregroundColor(DS.ink)
                .multilineTextAlignment(.center)

            if !content.verse.isEmpty {
                Rectangle()
                    .fill(DS.bronze.opacity(0.25))
                    .frame(width: 44, height: 1)
                Text(content.verse)
                    .font(.custom("Georgia", size: 16, relativeTo: .body))
                    .italic()
                    .foregroundColor(DS.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            if !content.note.isEmpty {
                Text(content.note)
                    .font(.custom("Georgia", size: 14, relativeTo: .caption))
                    .foregroundColor(DS.inkSoft.opacity(0.75))
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
                        .foregroundColor(DS.ink)
                    Text(AppState.tr("share_card_download_hint"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let attr = content.attribution, !attr.isEmpty {
                        Text(attr)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(DS.bronze)
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(28)
        .frame(width: 340, height: 480)
        .paperBackground()
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(DS.bronze.opacity(0.3), lineWidth: 1)
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
                    .background(DS.ink)
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
