import SwiftUI

// MARK: - Journal View

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEntry: JournalEntry?
    @State private var showDetail = false
    @State private var showExport = false

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
                    // Free tier: journal limit banner
                    if !subscriptionManager.isPro {
                        Section {
                            Button(action: { subscriptionManager.showingPaywall = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(String(format: AppState.tr("free_journal_limit_fmt"), SeekWisdomView.freeJournalLimit))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(AppState.tr("Upgrade"))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                                }
                            }
                        }
                    }

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
                .listStyle(.insetGrouped)
                .refreshable {
                    await loadEntries()
                }
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Export journal — Pro-only
                Button {
                    if subscriptionManager.isPro {
                        showExport = true
                    } else {
                        subscriptionManager.showingPaywall = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(AppState.tr("Export Journal"))
            }
        }
        .sheet(isPresented: $showDetail) {
            if let entry = selectedEntry {
                JournalEntryDetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showExport) {
            ShareSheet(activityItems: [exportText])
        }
        .task {
            await loadEntries()
        }
    }

    /// Build a plain-text export of the journal (Pro feature)
    private var exportText: String {
        var text = "☯ TaoMind Journal\n"
        text += "\(entries.count) entries\n"
        text += "──────────────\n\n"
        for (index, entry) in entries.enumerated() {
            text += "\(index + 1). \(entry.question)\n"
            text += "   \(entry.formattedDate)\n"
            if !entry.passage.isEmpty {
                text += "   📜 \(entry.passage)\n"
            }
            if !entry.wisdom.isEmpty {
                text += "   🌿 \(entry.wisdom)\n"
            }
            if !entry.reflection.isEmpty {
                text += "   🪞 \(entry.reflection)\n"
            }
            if !entry.way_forward.isEmpty {
                text += "   💧 \(entry.way_forward)\n"
            }
            text += "\n"
        }
        return text
    }

    private func loadEntries() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.listJournal()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                entries = result
                isLoading = false
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
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

            if !entry.wisdom.isEmpty {
                Text(entry.wisdom)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
