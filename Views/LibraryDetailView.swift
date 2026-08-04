import SwiftUI

// MARK: - Library Detail (经文详情)

struct LibraryDetailView: View {
    let entry: LibraryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Attribution
                Text("\(entry.source) · \(entry.chapter)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Verse
                Text(entry.verse_text)
                    .font(.custom("Georgia", size: 18, relativeTo: .body))
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Commentary (白话精讲)
                if !entry.commentary.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("Commentary"))
                            .font(.headline)
                            .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                        Text(entry.commentary)
                            .font(.body)
                            .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.16))
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(14)
                }

                // Reflection
                if !entry.reflection.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("The Reflection"))
                            .font(.headline)
                            .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                        Text(entry.reflection)
                            .font(.custom("Georgia", size: 16, relativeTo: .body))
                            .italic()
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                }
            }
            .padding()
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .navigationTitle(entry.chapter)
        .navigationBarTitleDisplayMode(.inline)
    }
}
