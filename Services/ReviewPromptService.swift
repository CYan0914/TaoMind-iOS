import Foundation
import StoreKit
import UIKit

// MARK: - Review Prompt Service (评分弹窗)

/// Wraps `SKStoreReviewController.requestReview()` with milestone gating.
///
/// Apple limits the OS-level prompt to ≤3 times per 365-day window per app, so the
/// three exits are deliberately capped:
///   ① 第 2 次求取智慧成功 — 用户刚拿到价值，情绪最高
///   ② 连续打卡 3 天     — 用户在养成习惯，满意度最高
///   ③ Settings → "Rate TaoMind" — 用户主动，不算打扰
///
/// 前两个由 `promptAfterSeek` / `promptOnStreak` 触发，各只弹一次；
/// `promptNow()` 不受里程碑门槛限制。
@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

    private let defaults = UserDefaults.standard
    private let promptedSeek2Key = "review.prompted.at2seeks"
    private let promptedStreak3Key = "review.prompted.atStreak3"
    private let lastPromptedKey = "review.last_prompted_at"

    private init() {}

    /// 第 2 次求取智慧成功时调用（传 `AppState.totalSeekCount`）。仅弹一次。
    func promptAfterSeek(totalSeeks: Int) {
        guard totalSeeks >= 2, !defaults.bool(forKey: promptedSeek2Key) else { return }
        requestReview()
        defaults.set(true, forKey: promptedSeek2Key)
    }

    /// 连续打卡满 3 天时调用（传 `streak.currentStreak`）。仅弹一次。
    func promptOnStreak(_ currentStreak: Int) {
        guard currentStreak >= 3, !defaults.bool(forKey: promptedStreak3Key) else { return }
        requestReview()
        defaults.set(true, forKey: promptedStreak3Key)
    }

    /// Unconditional prompt: used by the "Rate TaoMind" row in Settings.
    /// Apple may still suppress the sheet (e.g. recently shown by another code
    /// path), but it costs us nothing to try.
    func promptNow() {
        requestReview()
    }

    private func requestReview() {
        // Cooldown 1 day between attempts — guards against users reopening
        // the app rapidly, and blocks the "第 2 次 seek / 连续打卡 3 天" double-fire
        // when both milestones land on the same day.
        if let last = defaults.object(forKey: lastPromptedKey) as? Date,
           Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        defaults.set(Date(), forKey: lastPromptedKey)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            SKStoreReviewController.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview()
        }
    }
}
