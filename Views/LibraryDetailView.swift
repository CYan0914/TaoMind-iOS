import SwiftUI

// MARK: - Library Detail (经文详情)

struct LibraryDetailView: View {
    let entry: LibraryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    /// 分享的是当前语言的整篇正文。标题用本地化后的章节名，
    /// 这样英文界面分享出去是 Talk Six…，不会混进中文讲次。
    private var shareText: String {
        "\(entry.localizedChapter)\n\n\(entry.localizedVerse)"
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
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(AppState.tr("Share"))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
}
