import SwiftUI

// MARK: - Mood Chip Row (build 50: 情绪化每日经文)
//
// 1 行 4 chip · 点击 toggle 选中态。
// 仅 isSignedIn 时显示（未登录走 signedOutContent）。
// iOS 16 兼容：不用 `containerShape` / `safeAreaPadding`。

struct MoodChipRow: View {
    @Binding var selected: Mood?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppState.tr("mood_row_title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DS.ink)
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    moodChip(mood)
                }
            }
        }
    }

    private func moodChip(_ mood: Mood) -> some View {
        let isSelected = (selected == mood)
        return Button {
            // toggle:再点取消(允许用户撤回到无 mood → 不重 LLM 但 UI 提示)
            selected = isSelected ? nil : mood
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: 28))
                Text(AppState.tr(mood.displayKey))
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? DS.bronzeDeep : DS.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? DS.bronze.opacity(0.10) : DS.paperHi)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(isSelected ? DS.bronze : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppState.tr(mood.displayKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
