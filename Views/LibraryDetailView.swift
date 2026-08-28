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
                    .foregroundColor(DS.ink)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Commentary (白话精讲)
                if !entry.commentary.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("Commentary"))
                            .font(.headline)
                            .foregroundColor(DS.ink)
                        Text(entry.commentary)
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
                if !entry.reflection.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppState.tr("The Reflection"))
                            .font(.headline)
                            .foregroundColor(DS.ink)
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
        .paperBackground()
        .navigationTitle(entry.chapter)
        .navigationBarTitleDisplayMode(.inline)
    }
}
