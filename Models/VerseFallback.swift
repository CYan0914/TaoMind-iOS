import Foundation

// MARK: - Offline Verse Cache

/// Provides a fallback collection of verses when the API is unreachable.
struct VerseFallback {
    static let verses: [(source: String, chapter: String, text: String, reflection: String)] = [
        (
            source: "Tao Te Ching", chapter: "Chapter 1",
            text: "The Tao that can be told is not the eternal Tao. The name that can be named is not the eternal name.",
            reflection: "What cannot be named in your life right now?"
        ),
        (
            source: "Tao Te Ching", chapter: "Chapter 8",
            text: "The highest good is like water. Water benefits all things without striving. It flows to places people disdain — and thus it is close to the Tao.",
            reflection: "Where in your life are you striving when you could be flowing like water?"
        ),
        (
            source: "Tao Te Ching", chapter: "Chapter 15",
            text: "Do you have the patience to wait until your mud settles and the water is clear? Can you remain unmoving until the right action arises by itself?",
            reflection: "What decision are you rushing that would benefit from stillness?"
        ),
        (
            source: "Tao Te Ching", chapter: "Chapter 33",
            text: "Knowing others is intelligence; knowing yourself is true wisdom. Mastering others is strength; mastering yourself is true power.",
            reflection: "Do you spend more energy understanding others or understanding yourself?"
        ),
        (
            source: "Diamond Sutra", chapter: "Chapter 32",
            text: "Like a dream, a fantasy, a bubble, a shadow, like dew or a flash of lightning — thus shall you view all formed things.",
            reflection: "If you knew this problem was like a passing cloud, how would you respond differently?"
        ),
        (
            source: "Tao Te Ching", chapter: "Chapter 64",
            text: "A journey of a thousand miles begins with a single step. The master arrives without leaving, sees the light without looking, achieves without striving.",
            reflection: "What 'thousand-mile journey' are you avoiding because the first step feels too small?"
        ),
        (
            source: "Diamond Sutra", chapter: "Chapter 10",
            text: "Let your mind arise without abiding anywhere. Let it flow freely, not grasping at any object, not settling in any place.",
            reflection: "Where is your mind stuck on a fixed outcome that needs to be released?"
        ),
    ]

    static func verseForToday() -> (source: String, chapter: String, text: String, reflection: String) {
        let day = Calendar.current.component(.day, from: Date())
        let idx = (day - 1) % verses.count
        return verses[idx]
    }
}
