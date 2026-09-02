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
                VStack { Divider().frame(height: 1).background(DS.bronze.opacity(0.3)) }
                Text("The Sage Speaks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                VStack { Divider().frame(height: 1).background(DS.bronze.opacity(0.3)) }
            }

            // Passage
            WisdomSection(
                icon: "经",
                title: AppState.tr("The Passage"),
                content: result.passage
            )

            // Wisdom
            WisdomSection(
                icon: "释",
                title: AppState.tr("The Wisdom"),
                content: result.wisdom
            )

            // Reflection
            WisdomSection(
                icon: "思",
                title: AppState.tr("The Reflection"),
                content: result.reflection
            )

            // Way Forward
            WisdomSection(
                icon: "行",
                title: AppState.tr("The Way Forward"),
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
                        .background(DS.ink.opacity(0.045))
                        .cornerRadius(DS.Radius.small)
                }

                // Copy
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DS.ink.opacity(0.045))
                        .cornerRadius(DS.Radius.small)
                }

                // Favorite
                Button(action: { withAnimation { isFavorite.toggle() } }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorite ? DS.cinnabar : DS.inkFaint)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.small)
                                .fill(DS.ink.opacity(0.045))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.small)
                                .stroke(DS.bronze.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 8)

            // Copied toast
            if showCopiedToast {
                Text(AppState.tr("Copied to clipboard ✨"))
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
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DS.cinnabar)
                        .frame(width: 3, height: 14)
                    Text(title)
                        .font(DS.title(16))
                        .foregroundColor(DS.ink)
                }

                // 修设计审计 2026-09-02 Blocker 1：用 AttributedString 解析后端返回的
                // markdown（*italic* / **bold**），去掉 AI 常带的 --- 分隔行。
                // 见 DesignSystem.swift 顶部 `extension Text { static func markdown }`。
                Text.markdown(content)
                    .font(DS.verse(15, relativeTo: .body))
                    .foregroundColor(DS.inkSoft)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 26)
            }
            // 竖排题字侧注（经/释/思/行）
            Text(icon)
                .font(DS.display(22, weight: .black, relativeTo: .title3))
                .foregroundColor(DS.cinnabar.opacity(0.5))
                .padding(.top, 2)
                .padding(.trailing, 2)
        }
        .paperCard()
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
