import SwiftUI
import UIKit

// MARK: - Library Detail (经文详情)

struct LibraryDetailView: View {
    let entry: LibraryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: ShareSheetKind?

    /// 文字分享带上落地页链接：微信只对 URL 生成预览卡片，
    /// 纯文本（整篇 1-2 万字）在微信里发不出去。
    private var shareText: String {
        let excerptText = excerpt(entry.localizedVerse, limit: 220)
        let link = "https://taomindapp.com/s/\(entry.display_order)"
        return "\(entry.localizedChapter)\n\n\(excerptText)\n\n\(AppState.tr("share_read_full")) \(link)"
    }

    /// 微信分享只稳定支持图片和链接，纯文本（讲次全文 1-2 万字）超出
    /// 微信单条消息上限，分享扩展会直接失败或根本不出现。改为图片卡片。
    private var cardContent: ShareCardContent {
        ShareCardContent(
            title: entry.localizedChapter,
            verse: excerpt(entry.localizedVerse),
            note: "",
            subtitle: "TaoMind · \(entry.source)",
            attribution: nil
        )
    }

    /// 卡片版位有限：取正文开头，尽量在句末截断，避免半个句子。
    /// 上限 110 字 —— ShareCardView 固定 340x480，150 字会挤掉底部二维码。
    private func excerpt(_ text: String, limit: Int = 110) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > limit else { return flat }
        let head = String(flat.prefix(limit))
        let stops: Set<Character> = ["。", "！", "？", "；", ".", "!", "?", ";"]
        if let cut = head.lastIndex(where: { stops.contains($0) }),
           head.distance(from: head.startIndex, to: cut) >= 40 {
            return String(head[...cut])
        }
        return head + "……"
    }

    private enum ShareSheetKind: Int, Identifiable {
        case card, text
        var id: Int { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Attribution
                Text("\(entry.source) · \(entry.localizedChapter)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Verse
                Text(entry.localizedVerse)
                    .font(.custom("Georgia", size: 18, relativeTo: .body))
                    .foregroundColor(DS.ink)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Commentary (白话精讲)
                if !entry.localizedCommentary.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("Commentary"))
                            .font(.headline)
                            .foregroundColor(DS.ink)
                        Text(entry.localizedCommentary)
                            .font(.body)
                            .foregroundColor(DS.inkSoft)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.paperHi)
                    .cornerRadius(14)
                }

                // Reflection
                if !entry.localizedReflection.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("The Reflection"))
                            .font(.headline)
                            .foregroundColor(DS.ink)
                        Text(entry.localizedReflection)
                            .font(.custom("Georgia", size: 16, relativeTo: .body))
                            .italic()
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                }
            }
            .padding()
            // 展开态限宽：经文 + 精讲 + 感悟三段长文，铺满内屏宽会读成横线。
            // 限到 640 居中；窄屏可用宽本就不足 640，行为不变。
            .readableColumn(max: 640)
        }
        .paperBackground()
        .navigationTitle(entry.localizedChapter)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text(AppState.tr("Back"))
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        activeSheet = .card
                    } label: {
                        Label(AppState.tr("share_as_card"), systemImage: "photo")
                    }
                    Button {
                        activeSheet = .text
                    } label: {
                        Label(AppState.tr("share_as_text"), systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(AppState.tr("Share"))
            }
        }
        .sheet(item: $activeSheet) { kind in
            switch kind {
            case .card:
                LibraryShareCardSheet(content: cardContent)
            case .text:
                ShareSheet(activityItems: [shareText])
            }
        }
    }
}

// MARK: - Library Share Card

/// 经藏详情页的图片分享：卡片自带 App Store 二维码，纯图片也能带回下载。
/// 独立于 ShareCardPreviewSheet —— 后者用 medium detent，480pt 卡片会被裁掉。
private struct LibraryShareCardSheet: View {
    let content: ShareCardContent
    @Environment(\.displayScale) private var displayScale
    @State private var showShareSheet = false
    @State private var rendered: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ShareCardView(content: content)
                    .padding(.vertical, 20)
            }
            Button {
                rendered = ShareCardRenderer.image(for: content, scale: displayScale)
                if rendered != nil { showShareSheet = true }
            } label: {
                Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [DS.bronzeLight, DS.bronzeDeep],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .foregroundColor(DS.paperHi)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .background(DS.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .sheet(isPresented: $showShareSheet) {
            if let rendered {
                ShareSheet(activityItems: [rendered])
            }
        }
    }
}
