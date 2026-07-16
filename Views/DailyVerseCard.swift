import SwiftUI

// MARK: - Daily Verse Card

struct DailyVerseCard: View {
    let verse: DailyVerse

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Daily Verse")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Text(verse.verse_text)
                .font(.custom("Georgia", size: 16, relativeTo: .body))
                .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                .lineSpacing(6)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("—")
                    .foregroundColor(.secondary)
                Text(verse.source)
                    .fontWeight(.semibold)
                if !verse.chapter.isEmpty {
                    Text("· \(verse.chapter)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text(verse.reflection)
                .font(.custom("Georgia", size: 14, relativeTo: .footnote))
                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.25))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(Color(red: 0.95, green: 0.93, blue: 0.9))
                .cornerRadius(10)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.18).opacity(0.15), lineWidth: 1)
        )
    }
}
