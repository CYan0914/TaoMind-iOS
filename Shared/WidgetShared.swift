import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 主 App 与 Widget 之间的数据桥。
///
/// Widget 跑在独立进程里，读不到主 App 的 UserDefaults。今日经文、连续天数
/// 这类「每天都会变、用户在主屏就想看见」的状态必须经 App Group 共享。
/// 数据缺失时 Widget 退化成一张引导卡，不会白屏。
enum WidgetSharedStore {
    static let appGroupID = "group.com.cyan0914.taomind"

    enum Key {
        static let verse = "widget.verse"
        static let source = "widget.source"
        static let streak = "widget.streak"
        static let done = "widget.done"
        static let updatedAt = "widget.updatedAt"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// 主 App 侧调用：把当前状态写进共享容器并触发 Widget 刷新。
    static func publish(verse: String, source: String, streak: Int, done: Bool) {
        guard let d = defaults else { return }
        d.set(verse, forKey: Key.verse)
        d.set(source, forKey: Key.source)
        d.set(streak, forKey: Key.streak)
        d.set(done, forKey: Key.done)
        d.set(Date(), forKey: Key.updatedAt)
        reload()
    }

    /// 打卡状态变化时只需要改这两个字段，经文保持不动。
    static func publishStreak(_ streak: Int, done: Bool) {
        guard let d = defaults else { return }
        d.set(streak, forKey: Key.streak)
        d.set(done, forKey: Key.done)
        d.set(Date(), forKey: Key.updatedAt)
        reload()
    }

    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - 读（Widget 侧）

    static var verse: String { defaults?.string(forKey: Key.verse) ?? "" }
    static var source: String { defaults?.string(forKey: Key.source) ?? "" }
    static var streak: Int { defaults?.integer(forKey: Key.streak) ?? 0 }
    static var done: Bool { defaults?.bool(forKey: Key.done) ?? false }
}
