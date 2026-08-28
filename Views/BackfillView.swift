import SwiftUI

// MARK: - Backfill View (补卡)

struct BackfillView: View {
    let targetDate: String          // "yyyy-MM-dd"
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reflection: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = CheckinService()

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: targetDate) else { return targetDate }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: d)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppState.tr("backfill_explain"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                Label(formattedDate, systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(DS.ink)

                ZStack(alignment: .topLeading) {
                    if reflection.isEmpty {
                        Text(AppState.tr("backfill_placeholder"))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    TextEditor(text: $reflection)
                        .font(.body)
                        .frame(minHeight: 140)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(DS.ink.opacity(0.045))
                        .cornerRadius(DS.Radius.card)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(DS.cinnabar)
                }

                Spacer()

                Button(action: save) {
                    HStack(spacing: 12) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal")
                        }
                        Text(AppState.tr("complete_practice"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(reflection.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.3)
                                : DS.ink)
                    .foregroundColor(reflection.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .white)
                    .cornerRadius(14)
                }
                .disabled(reflection.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding()
            .navigationTitle(AppState.tr("Backfill"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppState.tr("Close")) { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func save() {
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        Task {
            do {
                _ = try await service.backfill(reflection: text, verseText: "", source: "verse")
                await MainActor.run { dismiss() }
                onSaved()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            isSaving = false
        }
    }
}
