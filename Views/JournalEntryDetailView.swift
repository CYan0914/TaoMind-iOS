import SwiftUI

// MARK: - Journal Entry Detail View

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @State private var notes: String = ""
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Question
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Question")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(entry.question)
                            .font(.custom("Georgia", size: 18, relativeTo: .title3))
                            .foregroundColor(DS.ink)

                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text(entry.scenario_type.replacingOccurrences(of: "_", with: " ").capitalized)
                            Text("·")
                            Text(entry.formattedDate)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Divider()

                    // Passage
                    if !entry.passage.isEmpty {
                        DetailSection(title: AppState.tr("📜 The Passage"), content: entry.passage)
                    }

                    // Wisdom
                    if !entry.wisdom.isEmpty {
                        DetailSection(title: AppState.tr("🌿 The Wisdom"), content: entry.wisdom)
                    }

                    // Reflection
                    if !entry.reflection.isEmpty {
                        DetailSection(title: AppState.tr("🪞 The Reflection"), content: entry.reflection)
                    }

                    // Way Forward
                    if !entry.way_forward.isEmpty {
                        DetailSection(title: AppState.tr("💧 The Way Forward"), content: entry.way_forward)
                    }

                    Divider()

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Notes")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(DS.ink.opacity(0.045))
                            .cornerRadius(DS.Radius.card)

                        Button("Save Notes") {
                            // Notes saving not yet implemented on backend
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(DS.ink.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(DS.Radius.small)
                        .disabled(true)
                    }
                }
                .padding()
            }
            .paperBackground()
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !hasLoaded {
                    notes = entry.notes ?? ""
                    hasLoaded = true
                }
            }
        }
    }
}

struct DetailSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DS.ink)
            Text(content)
                .font(.custom("Georgia", size: 15, relativeTo: .body))
                .foregroundColor(DS.inkSoft)
                .lineSpacing(6)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.paperHi)
                .cornerRadius(DS.Radius.small)
        }
    }
}
