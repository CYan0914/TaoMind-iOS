import Foundation
import StoreKit
import UIKit

// MARK: - Review Prompt Service (评分弹窗)

/// Wraps `SKStoreReviewController.requestReview()` with milestone gating.
///
/// Apple limits the OS-level prompt to ≤3 times per 365-day window per app, so we
/// additionally gate it by check-in count: trigger only at 7-day and 30-day
/// milestones, and only if we have not already prompted at that milestone.
///
/// The Settings → "Rate TaoMind" row calls `promptNow()` which is the
/// "always-on" exit hatch and is not subject to the milestone gate.
@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

    private let defaults = UserDefaults.standard
    private let prompted7Key = "review.prompted.at7"
    private let prompted30Key = "review.prompted.at30"
    private let lastPromptedKey = "review.last_prompted_at"

    private init() {}

    /// If the user is hitting a check-in milestone (7 or 30 total checkins) and we
    /// have not prompted at this milestone before, ask the OS to show the rating
    /// sheet. Safe to call on every view appearance — the gate prevents spam.
    func promptIfAtMilestone(totalCheckins: Int) {
        guard totalCheckins >= 7 else { return }

        // 7-day milestone
        if totalCheckins >= 7, !defaults.bool(forKey: prompted7Key) {
            requestReview()
            defaults.set(true, forKey: prompted7Key)
            return
        }

        // 30-day milestone (only meaningful after the 7-day mark)
        if totalCheckins >= 30, !defaults.bool(forKey: prompted30Key) {
            requestReview()
            defaults.set(true, forKey: prompted30Key)
            return
        }
    }

    /// Unconditional prompt: used by the "Rate TaoMind" row in Settings.
    /// Apple may still suppress the sheet (e.g. recently shown by another code
    /// path), but it costs us nothing to try.
    func promptNow() {
        requestReview()
    }

    private func requestReview() {
        // Cooldown 1 day between attempts — guards against users reopening
        // the app rapidly and triggering repeat requests.
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
