import SwiftUI

// MARK: - Library (经藏)

struct LibraryView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var entries: [LibraryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEntry: LibraryEntry?

    private let api = APIClient()
    /// Free tier can read the first 5 chapters of each source as a taste.
    private let freeTasteCount = 5

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(AppState.tr("Retry")) {
                            Task { await load() }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.17, green: 0.14, blue: 0.09))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    libraryList
                }
            }
            .navigationTitle(AppState.tr("Library"))
            .task { await load() }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LibraryDetailView(entry: entry)
            }
        }
    }

    private var libraryList: some View {
        List {
            Section(header: Text("《道德经》 · Tao Te Ching")) {
                ForEach(ttcEntries) { entry in
                    libraryRow(entry)
                }
            }
            Section(header: Text("《金刚经》 · Diamond Sutra")) {
                ForEach(diamondEntries) { entry in
                    libraryRow(entry)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func libraryRow(_ entry: LibraryEntry) -> some View {
        let locked = isLocked(entry)
        return Button {
            open(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.chapter)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.17, green: 0.14, blue: 0.09))
                    Text(entry.verse_text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var ttcEntries: [LibraryEntry] { entries.filter { $0.source == "Tao Te Ching" } }
    private var diamondEntries: [LibraryEntry] { entries.filter { $0.source == "Diamond Sutra" } }

    private func isLocked(_ entry: LibraryEntry) -> Bool {
        guard !subscriptionManager.isPro else { return false }
        let sameSource = entries.filter { $0.source == entry.source }
        let index = sameSource.firstIndex { $0.display_order == entry.display_order } ?? 0
        return index >= freeTasteCount
    }

    private func open(_ entry: LibraryEntry) {
        if isLocked(entry) {
            subscriptionManager.showingPaywall = true
            return
        }
        selectedEntry = entry
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.fetchLibrary()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                entries = result.entries
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
}
