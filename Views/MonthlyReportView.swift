import SwiftUI

// MARK: - Monthly Report View (修习月报)

struct MonthlyReportView: View {
    let month: String                 // "YYYY-MM"
    @Environment(\.dismiss) private var dismiss
    @State private var report: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var shareCardContent: ShareCardContent?

    private let service = CheckinService()

    private var monthLabel: String {
        let parts = month.split(separator: "-")
        guard parts.count == 2 else { return month }
        return "\(parts[0])年\(parts[1])月"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    } else if let err = errorMessage {
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else if let report {
                        Text(report)
                            .font(.custom("Georgia", size: 16, relativeTo: .body))
                            .foregroundColor(DS.inkSoft)
                            .lineSpacing(7)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: share) {
                            Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DS.ink)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .paperBackground()
            .navigationTitle("\(monthLabel) · \(AppState.tr("monthly_report"))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppState.tr("Close")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(item: $shareCardContent) { content in
            ShareCardPreviewSheet(content: content)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let result = try await service.fetchMonthlyReport(month: month)
            await MainActor.run {
                report = result.report
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = AppState.tr("monthly_report_empty")
                isLoading = false
            }
        }
    }

    private func share() {
        let note = report.map { String($0.prefix(120)) + "…" } ?? ""
        shareCardContent = ShareCardContent(
            title: "\(monthLabel) · \(AppState.tr("monthly_report"))",
            verse: "",
            note: note,
            subtitle: AppState.tr("share_card_subtitle"),
            attribution: monthlyAttribution()
        )
    }

    private func monthlyAttribution() -> String? {
        guard let name = AuthService.shared.user?.display_name, !name.isEmpty else { return nil }
        // 简单格式：@handle 在 2026年8月 修行报告（不混用 referral_footer_fmt，避免数字语义错位）
        let handle = name
        return String(format: AppState.tr("referral_monthly_fmt"), handle, monthLabel)
    }
}
