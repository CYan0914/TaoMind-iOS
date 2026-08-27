import Foundation

/// 轻量自建漏斗埋点：fire-and-forget 打到自家后端 /analytics/track。
/// 只上报事件名与非内容属性（弹墙场景、套餐 id、卡编号）——绝不上报用户输入内容。
/// 后端未部署/离线时静默失败，不影响任何功能路径。
@MainActor
enum Analytics {
    static func track(_ event: String, _ properties: [String: String] = [:]) {
        Task {
            try? await APIClient().trackEvent(event: event, properties: properties)
        }
    }

    // 语义化便捷入口（事件名必须与后端 TRACKABLE_EVENTS 白名单一致）
    static func paywallView(context: PaywallContext) {
        track("paywall_view", ["context": String(describing: context)])
    }
    static func purchaseStart(packageID: String) { track("purchase_start", ["package": packageID]) }
    static func purchaseSuccess(packageID: String) { track("purchase_success", ["package": packageID]) }
    static func purchaseFail(packageID: String) { track("purchase_fail", ["package": packageID]) }
    static func cardUnlocked(number: Int) { track("card_unlocked", ["number": "\(number)"]) }
    static func collectionOpened() { track("collection_opened") }
}
