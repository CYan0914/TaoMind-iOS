import WidgetKit
import SwiftUI

// MARK: - Entry

struct TaoMindEntry: TimelineEntry {
    let date: Date
    let verse: String
    let source: String
    let streak: Int
    let done: Bool
}

// MARK: - Provider

struct TaoMindProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaoMindEntry {
        TaoMindEntry(
            date: Date(),
            verse: "上善若水。水善利万物而不争。",
            source: "道德经 · 第八章",
            streak: 12,
            done: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaoMindEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaoMindEntry>) -> Void) {
        let entry = currentEntry()
        // 共享数据只在主 App 打开时更新；每小时取一次即可，
        // 真正变化时主 App 会主动 reloadAllTimelines 立刻刷新。
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> TaoMindEntry {
        TaoMindEntry(
            date: Date(),
            verse: WidgetSharedStore.verse,
            source: WidgetSharedStore.source,
            streak: WidgetSharedStore.streak,
            done: WidgetSharedStore.done
        )
    }
}

// MARK: - View

struct TaoMindWidgetEntryView: View {
    let entry: TaoMindEntry
    @Environment(\.widgetFamily) private var family

    private var ink: Color { Color(red: 0.12, green: 0.11, blue: 0.09) }
    private var paper: Color { Color(red: 0.99, green: 0.98, blue: 0.96) }
    private var bronze: Color { Color(red: 0.62, green: 0.45, blue: 0.22) }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("☯")
                    .font(.system(size: 12))
                    .foregroundColor(bronze)
                Text(entry.done ? "已完成" : streakText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(entry.done ? bronze : ink.opacity(0.75))
                Spacer(minLength: 0)
            }

            Text(entry.verse.isEmpty ? "打开 TaoMind 读今日经文" : entry.verse)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(ink)
                .lineSpacing(2)
                .lineLimit(family == .systemSmall ? 5 : 3)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if !entry.source.isEmpty {
                Text(entry.source)
                    .font(.system(size: 10))
                    .foregroundColor(ink.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var streakText: String {
        entry.streak > 0 ? "第 \(entry.streak) 天" : "今日功课"
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { paper }
        } else {
            content.background(paper)
        }
    }
}

// MARK: - Widget

struct TaoMindWidget: Widget {
    let kind = "TaoMindWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaoMindProvider()) { entry in
            TaoMindWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日经文")
        .description("主屏查看今日经文与连续修习天数")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TaoMindWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaoMindWidget()
    }
}
