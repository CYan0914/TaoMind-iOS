import SwiftUI

// MARK: - Daily Verse Card

struct DailyVerseCard: View {
    let verse: DailyVerse

    var body: some View {
        VStack(spacing: 12) {
            Text(AppState.tr("daily_verse_eyebrow"))
                .eyebrowStyle()

            Text(verse.verse_text)
                .font(DS.verse(16, relativeTo: .body))
                .foregroundColor(DS.ink)
                .lineSpacing(6)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("—")
                    .foregroundColor(DS.inkFaint)
                Text(verse.source)
                    .fontWeight(.semibold)
                if !verse.chapter.isEmpty {
                    Text("· \(verse.chapter)")
                }
            }
            .font(.caption)
            .foregroundColor(DS.inkSoft)

            Text(verse.reflection)
                .font(DS.verse(14, relativeTo: .footnote))
                .foregroundColor(DS.inkSoft)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.ink.opacity(0.04))
                )
        }
        .padding(20)
        .paperCard()
    }
}
