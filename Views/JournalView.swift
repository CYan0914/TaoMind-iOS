import SwiftUI

// MARK: - Journal View

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEntry: JournalEntry?
    @State private var showDetail = false

    private let api = APIClient()

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading your journal...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Your Journal is Empty")
                        .font(.custom("Georgia", size: 20, relativeTo: .title2))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    Text("Every wisdom session is saved here.\nGo seek wisdom to fill your journal.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(entries) { entry in
                        JournalRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                                showDetail = true
                            }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.plain)
                .refreshable {
                    await loadEntries()
                }
            }
        }
        .navigationTitle("Journal")
        .sheet(isPresented: $showDetail) {
            if let entry = selectedEntry {
                JournalEntryDetailView(entry: entry)
            }
        }
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.listJournal()
            await MainActor.run {
                entries = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        // For now, local deletion only (API delete endpoint not implemented)
        entries.remove(atOffsets: offsets)
    }
}

// MARK: - Journal Row

struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.question)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    .lineLimit(2)

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 8) {
                Label(entry.scenario_type.replacingOccurrences(of: "_", with: " ").capitalized,
                      systemImage: "tag")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(entry.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let wisdom = entry.wisdom, !wisdom.isEmpty {
                Text(wisdom)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
