import SwiftUI
import UIKit

// MARK: - Referral View (推荐裂变页)

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ref = ReferralService.shared
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private let qrSize: CGFloat = 160

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headerCard

                    VStack(spacing: 14) {
                        Text(AppState.tr("referral_my_code"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(ref.myCode ?? "••••••••")
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(DS.ink)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(DS.ink.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DS.bronze.opacity(0.35), lineWidth: 1)
                    )

                    if let qr = QRCodeMaker.image(for: ref.shareURL ?? "https://taomindapp.com", size: qrSize * 2) {
                        VStack(spacing: 10) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: qrSize, height: qrSize)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(12)
                            Text(AppState.tr("referral_qr_hint"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    statsCard

                    Button {
                        generateShareImageAndShare()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(AppState.tr("referral_share_button"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DS.bronze)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(ref.myCode == nil)
                    .opacity(ref.myCode == nil ? 0.5 : 1.0)

                    if ref.lastRedeemSuccess {
                        Label(AppState.tr("referral_redeem_success"), systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    } else if let err = ref.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(DS.paper)
            .navigationTitle(AppState.tr("referral_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await ref.refresh()
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = shareImage {
                    ShareSheet(activityItems: [img])
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            Text("☯")
                .font(.system(size: 40))
            Text(AppState.tr("referral_title"))
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text(AppState.tr("referral_body"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(DS.bronze.opacity(0.08))
        .cornerRadius(16)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCol(value: "\(ref.inviteCount)", label: AppState.tr("referral_stat_invited"))
            Divider().frame(height: 36)
            statCol(value: "\(ref.totalGrantedDays)", label: AppState.tr("referral_stat_granted"))
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(DS.ink.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.bronze.opacity(0.35), lineWidth: 1)
        )
    }

    private func statCol(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(DS.ink)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func generateShareImageAndShare() {
        guard let code = ref.myCode else { return }
        let text = String(format: AppState.tr("referral_share_text_fmt"),
                          code, ref.shareURL ?? "")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 420))
        let img = renderer.image { ctx in
            let bg = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)
            ctx.cgContext.setFillColor(bg.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 420))

            // 头部图标
            let yinFont = UIFont.systemFont(ofSize: 64)
            ("☯" as NSString).draw(at: CGPoint(x: 360, y: 24), withAttributes: [.font: yinFont])

            // 标题
            let title = AppState.tr("referral_title")
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor(red: 0.17, green: 0.14, blue: 0.09, alpha: 1.0)
            ]
            (title as NSString).draw(in: CGRect(x: 40, y: 100, width: 720, height: 44),
                                     withAttributes: titleAttr)

            // 文案（多行）
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor(red: 0.43, green: 0.39, blue: 0.31, alpha: 1.0)
            ]
            (text as NSString).draw(in: CGRect(x: 40, y: 156, width: 720, height: 120),
                                    withAttributes: bodyAttr)

            // QR
            if let qr = QRCodeMaker.image(for: ref.shareURL ?? "https://taomindapp.com", size: 220) {
                qr.draw(in: CGRect(x: 60, y: 220, width: 160, height: 160))
            }

            // footer：品牌 + 域名
            let footer = "TaoMind · taomindapp.com"
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor(red: 0.60, green: 0.48, blue: 0.31, alpha: 1.0)
            ]
            (footer as NSString).draw(at: CGPoint(x: 240, y: 320), withAttributes: footerAttr)
        }
        self.shareImage = img
        self.showShareSheet = true
    }
}
