import UserNotifications
import SwiftUI

// MARK: - Daily Verse + Habit Loop Notification Service
//
// 时区说明：所有触发器（08:00 每日经文 / 18:00 断签预警 / 19:00 里程碑激励 / 10:00 断签召回）
// 都基于 `Calendar.current`，即用户设备的本地时区。这意味着 18:00 触发即用户本地 18:00
// ——对欧美用户是下班路上，对亚洲用户是饭后，无需 A/B。设备时区变更时 iOS 会按新时区
// 自动重算下次触发时间。
// 如未来要按用户偏好时段（如"早 8 点"vs"晚 9 点"）做 A/B，扩展点：
// `scheduleHabitNotifications(_ preferredWindow: ReminderWindow?)` 注释位。

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    private let apiBaseURL = "https://taomindapp.com"

    // 习惯闭环通知的稳定 identifier（取消/重排用）
    private let missWarningId = "habit-miss-warning"
    private let churnRecallId = "habit-churn-recall"
    private let milestoneIncentiveId = "habit-milestone-incentive"

    // MARK: - Authorization

    /// Request notification permission (called once at launch)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Notifications] Permission granted ✅")
            } else if let error = error {
                print("[Notifications] Permission denied: \(error.localizedDescription)")
            } else {
                print("[Notifications] Permission denied by user")
            }
        }
    }

    // MARK: - Schedule

    /// Fetch the daily verse and schedule tomorrow morning's notification
    func scheduleDailyVerse() async {
        // Cancel any existing pending notification first
        cancelScheduled()

        let verse = await fetchTodayVerse()

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = AppState.tr("☯ Daily Wisdom")
        content.subtitle = "\(verse.source) · \(verse.chapter)"
        content.body = verse.verse_text
        content.sound = .default

        // Schedule for tomorrow at 8:00 AM local time
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-verse",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[Notifications] Daily verse scheduled for 8:00 AM ✅")
        } catch {
            print("[Notifications] Failed to schedule: \(error)")
        }
    }

    /// Today's verse — API first, offline fallback. Shared by the morning push and the recall push.
    private func fetchTodayVerse() async -> DailyVerse {
        do {
            let client = APIClient(baseURL: apiBaseURL)
            return try await client.getDailyVerse()
        } catch {
            let fallback = VerseFallback.verseForToday()
            return DailyVerse(
                source: fallback.source,
                chapter: fallback.chapter,
                verse_text: fallback.text,
                reflection: fallback.reflection
            )
        }
    }

    /// Remove any scheduled daily verse notification
    func cancelScheduled() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-verse"])
    }

    // MARK: - Habit loop (习惯闭环：断签预警 / 断签召回 / 里程碑激励)

    /// 依据最新打卡状态重排三类习惯通知。App 启动、打卡成功后、回到前台时调用。
    /// 全部为本地一次性通知（非推送），当天时段已过则当天不触发，属预期行为。
    func scheduleHabitNotifications() async {
        // 打卡状态在服务端，未登录无法判断，直接跳过
        guard AuthService.shared.isSignedIn else { return }
        cancelHabitNotifications()
        do {
            let status = try await CheckinService().fetchStatus()
            let dates = Set(status.checkins.map { $0.checkin_date })
            let cal = Calendar.current
            let today = dayString(Date())
            let yesterday = dayString(cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            let streak = status.streak

            // 1) 断签预警：昨日已打卡、今日未打卡 → 18:00
            if dates.contains(yesterday) && !streak.todayDone {
                scheduleOneShot(
                    hour: 18, minute: 0, id: missWarningId,
                    title: AppState.tr("☯ Daily Wisdom"),
                    body: AppState.tr("miss_checkin_warning")
                )
            }

            // 2) 断签召回：连续 ≥2 天未打卡 → 10:00，推经文 + "连击还差一天恢复"
            if let last = streak.lastCheckinDate,
               let lastDate = Self.dayFormatter.date(from: last),
               let gap = cal.dateComponents([.day], from: lastDate, to: Date()).day,
               gap >= 2 {
                let verse = await fetchTodayVerse()
                scheduleOneShot(
                    hour: 10, minute: 0, id: churnRecallId,
                    title: AppState.tr("churn_recall_title"),
                    body: "\(verse.verse_text)\n\n\(AppState.tr("churn_recall_body"))"
                )
            }

            // 3) 里程碑激励：当前连续 N 天，明天恰好是里程碑（7/21/49/81）→ 19:00
            let milestones: Set<Int> = [7, 21, 49, 81]
            if !streak.todayDone && milestones.contains(streak.currentStreak + 1) {
                let target = streak.currentStreak + 1
                scheduleOneShot(
                    hour: 19, minute: 0, id: milestoneIncentiveId,
                    title: AppState.tr("milestone_incentive_title"),
                    body: AppState.tr("milestone_incentive_body_fmt", target)
                )
            }
        } catch {
            print("[Notifications] Habit scheduling failed: \(error)")
        }
    }

    /// Remove any scheduled habit-loop notification
    func cancelHabitNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [missWarningId, churnRecallId, milestoneIncentiveId]
        )
    }

    // MARK: - Check status

    /// Whether a daily verse notification is already scheduled
    func isScheduled() async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == "daily-verse" }
    }

    // MARK: - Helpers

    /// 一次性日历通知：当天该时刻未到则触发；已过则不触发（不重复）。
    private func scheduleOneShot(hour: Int, minute: Int, id: String, title: String, body: String) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] \(id) schedule failed: \(error)")
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func dayString(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }
}
