import UserNotifications
import SwiftUI

// MARK: - Daily Verse Notification Service

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    private let apiBaseURL = "https://observant-prosperity-production-92d3.up.railway.app"

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

        // Fetch verse (try API first, fallback to offline)
        let verse: DailyVerse
        do {
            let client = APIClient(baseURL: apiBaseURL)
            verse = try await client.getDailyVerse()
        } catch {
            let fallback = VerseFallback.verseForToday()
            verse = DailyVerse(
                source: fallback.source,
                chapter: fallback.chapter,
                verse_text: fallback.text,
                reflection: fallback.reflection
            )
        }

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = "☯ Daily Wisdom"
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

    /// Remove any scheduled daily verse notification
    func cancelScheduled() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-verse"])
    }

    // MARK: - Check status

    /// Whether a daily verse notification is already scheduled
    func isScheduled() async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == "daily-verse" }
    }
}
