import Foundation
import SwiftUI

// MARK: - Referral Service (推荐裂变客户端封装)

/// 推荐裂变单例。包装后端 3 个端点 + 处理 `taomind://referral/XXXXXXXX` deep link +
/// redeem 成功后触发 `SubscriptionManager.syncEntitlementToBackend()` 让 Pro 状态
/// 立即在前端刷新（不等 RevenueCat 推送）。
@MainActor
final class ReferralService: NSObject, ObservableObject {
    static let shared = ReferralService()

    @Published private(set) var myCode: String?
    @Published private(set) var shareURL: String?
    @Published private(set) var inviteCount: Int = 0
    @Published private(set) var totalGrantedDays: Int = 0
    @Published private(set) var pendingRedeemCode: String?  // 用户未登录时也暂存，登录后再 redeem
    @Published private(set) var lastRedeemSuccess: Bool = false
    @Published private(set) var lastError: String?

    private let api = APIClient()
    private let deepLinkScheme = "taomind"

    private override init() {
        super.init()
    }

    // MARK: - Load

    /// 拉取自己当前的邀请码 + 概况。登录后调用。
    func refresh() async {
        guard let token = AuthService.shared.token, !token.isEmpty else { return }
        do {
            let code = try await api.getMyReferralCode(authToken: token)
            self.myCode = code.code
            self.shareURL = code.shareURL
            let st = try await api.getReferralStatus(authToken: token)
            self.inviteCount = st.inviteCount
            self.totalGrantedDays = st.totalGrantedDays
        } catch {
            // 静默失败：不影响主流程；UI 暂保持上次值
        }
    }

    // MARK: - Redeem

    /// 用 8 位邀请码换双方各 7 天 Pro。成功会重读 entitlement。
    func redeem(code rawCode: String) async -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 8 else {
            self.lastError = "Invalid code"
            return false
        }
        guard let token = AuthService.shared.token, !token.isEmpty else {
            // 用户未登录：暂存到 UserDefaults，登录后自动重试
            UserDefaults.standard.set(code, forKey: "pending_referral_code")
            self.pendingRedeemCode = code
            return false
        }
        do {
            let resp = try await api.redeemReferral(code: code, authToken: token)
            self.lastRedeemSuccess = resp.ok
            self.lastError = nil
            // 触发后端重新校验 Pro + 拉新状态
            await SubscriptionManager.shared.syncEntitlementToBackend()
            await SubscriptionManager.shared.refreshStatus()
            await refresh()
            return resp.ok
        } catch {
            self.lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    /// App 启动 + 登录后调用：把之前从 deep link 暂存的码重试一次
    func tryPendingRedeem() async {
        if let saved = UserDefaults.standard.string(forKey: "pending_referral_code") {
            UserDefaults.standard.removeObject(forKey: "pending_referral_code")
            self.pendingRedeemCode = nil
            _ = await redeem(code: saved)
        }
    }

    // MARK: - Deep link

    /// `TaoMindApp.onOpenURL` 调用
    func handleDeepLink(_ url: URL) {
        // 形态：taomind://referral/ABCD1234
        guard url.scheme == deepLinkScheme,
              url.host == "referral" else { return }
        // 路径首位是 "/" + 8 位码
        let code = url.pathComponents.first(where: { $0.count == 8 })?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        guard code.count == 8 else { return }
        Task {
            if AuthService.shared.isSignedIn {
                _ = await redeem(code: code)
            } else {
                // 未登录：先暂存 + 切到注册流（AppState 已有 onboarding 路由）
                UserDefaults.standard.set(code, forKey: "pending_referral_code")
                self.pendingRedeemCode = code
            }
        }
    }
}
