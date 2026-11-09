import Foundation

// MARK: - Offline Verse Cache

/// API 不可达时的离线经文。
///
/// ⚠️ 中文槽不是可选项：这里曾只有英文七条，而 `loadDailyVerse()` 的 catch 分支
/// 把它们直接塞进 `DailyVerse.verse_text`（= 中文槽）。结果是中文界面在断网、
/// Cloudflare 抖动、后端 5xx 时永远显示英文经文 —— 「中文版显示英文」最稳定
/// 复现的一条通路。所以每条都带中文原文与中文反思，由 `dailyVerse(isEnglish:)`
/// 按界面语言组装。
struct VerseFallback {
    struct Entry {
        let source: String
        let chapter: String
        let chapterEn: String
        let text: String
        let textEn: String
        let reflection: String
        let reflectionEn: String
    }

    static let entries: [Entry] = [
        Entry(
            source: "道德经", chapter: "第一章", chapterEn: "Chapter 1",
            text: "道可道，非常道。名可名，非常名。",
            textEn: "The Tao that can be told is not the eternal Tao. The name that can be named is not the eternal name.",
            reflection: "此刻，你生活里有什么是无法命名的？",
            reflectionEn: "What cannot be named in your life right now?"
        ),
        Entry(
            source: "道德经", chapter: "第八章", chapterEn: "Chapter 8",
            text: "上善若水。水善利万物而不争，处众人之所恶，故几于道。",
            textEn: "The highest good is like water. Water benefits all things without striving. It flows to places people disdain — and thus it is close to the Tao.",
            reflection: "你正在哪里用蛮力，而本可以像水一样？",
            reflectionEn: "Where in your life are you striving when you could be flowing like water?"
        ),
        Entry(
            source: "道德经", chapter: "第十五章", chapterEn: "Chapter 15",
            text: "孰能浊以静之徐清？孰能安以动之徐生？",
            textEn: "Do you have the patience to wait until your mud settles and the water is clear? Can you remain unmoving until the right action arises by itself?",
            reflection: "有什么决定你正在催促，而它更需要静一静？",
            reflectionEn: "What decision are you rushing that would benefit from stillness?"
        ),
        Entry(
            source: "道德经", chapter: "第三十三章", chapterEn: "Chapter 33",
            text: "知人者智，自知者明。胜人者有力，自胜者强。",
            textEn: "Knowing others is intelligence; knowing yourself is true wisdom. Mastering others is strength; mastering yourself is true power.",
            reflection: "你花更多力气去懂别人，还是懂自己？",
            reflectionEn: "Do you spend more energy understanding others or understanding yourself?"
        ),
        Entry(
            source: "金刚经", chapter: "第三十二品", chapterEn: "Chapter 32",
            text: "一切有为法，如梦幻泡影，如露亦如电，应作如是观。",
            textEn: "Like a dream, a fantasy, a bubble, a shadow, like dew or a flash of lightning — thus shall you view all formed things.",
            reflection: "若你知道这件事如浮云过眼，你会怎样不同地回应？",
            reflectionEn: "If you knew this problem was like a passing cloud, how would you respond differently?"
        ),
        Entry(
            source: "道德经", chapter: "第六十四章", chapterEn: "Chapter 64",
            text: "千里之行，始于足下。",
            textEn: "A journey of a thousand miles begins with a single step. The master arrives without leaving, sees the light without looking, achieves without striving.",
            reflection: "哪一段「千里之行」你因为第一步太小而迟迟不动？",
            reflectionEn: "What 'thousand-mile journey' are you avoiding because the first step feels too small?"
        ),
        Entry(
            source: "金刚经", chapter: "第十品", chapterEn: "Chapter 10",
            text: "应无所住，而生其心。",
            textEn: "Let your mind arise without abiding anywhere. Let it flow freely, not grasping at any object, not settling in any place.",
            reflection: "你的心卡在哪个必须实现的结果上？",
            reflectionEn: "Where is your mind stuck on a fixed outcome that needs to be released?"
        ),
    ]

    static func entryForToday() -> Entry {
        let day = Calendar.current.component(.day, from: Date())
        let idx = (day - 1) % entries.count
        return entries[idx]
    }

    /// 按界面语言组装一份 `DailyVerse`：中文进主字段，英文进 `_en` 三列，
    /// 两列都填 —— 这样用户在离线状态下切换语言也能立刻换字，不必等网络。
    @MainActor
    static func dailyVerse(isEnglish: Bool) -> DailyVerse {
        let e = entryForToday()
        return DailyVerse(
            source: isEnglish ? e.sourceEnglish : e.source,
            chapter: e.chapter,
            verse_text: e.text,
            reflection: e.reflection,
            chapter_en: e.chapterEn,
            verse_text_en: e.textEn,
            reflection_en: e.reflectionEn
        )
    }

}

private extension VerseFallback.Entry {
    /// 英文界面的 source 名（后端英文条目用的是 Tao Te Ching / Diamond Sutra）。
    var sourceEnglish: String {
        switch source {
        case "道德经": return "Tao Te Ching"
        case "金刚经": return "Diamond Sutra"
        default: return source
        }
    }
}
