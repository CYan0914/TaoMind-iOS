import Foundation

// MARK: - 精讲内容服务 (Tao Te Ching · In-Depth)
//
// Loads `jingjiang.json` from the app bundle ONCE and caches the result in memory.
// All UI reads from `shared.chapters`. 36 chapters ≈ 470KB, fits in RAM without issue.
//
// Free taste: 1 chapter (chapter 1) is always unlocked.
// Pro: all 36 chapters unlocked.

@MainActor
final class JingjiangService: ObservableObject {
    static let shared = JingjiangService()

    @Published private(set) var chapters: [JingjiangChapter] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: String?

    /// Free chapter count for 精讲 (3 chapters taste for non-Pro users).
    /// Per product decision 2026-09-04: 3 章试读 — ch01 (道可道) / ch02 (美丑相依) / ch03 (不尚贤).
    /// Updated from 1 → 3 to widen the funnel after 36→81 chapter expansion.
    static let freeChapterCount = 3

    private init() {}

    /// Eager load (call from TaoMindApp init for first-paint perf).
    func load() {
        guard !isLoaded, chapters.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "jingjiang", withExtension: "json") else {
            loadError = "jingjiang.json not found in bundle"
            print("[Jingjiang] ❌ \(loadError ?? "")")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(JingjiangBundle.self, from: data)
            self.chapters = bundle.chapters
            self.isLoaded = true
            print("[Jingjiang] ✅ loaded \(chapters.count) chapters")
        } catch {
            loadError = "JSON decode failed: \(error.localizedDescription)"
            print("[Jingjiang] ❌ \(loadError ?? "")")
        }
    }

    /// Look up a chapter by 1-based number.
    func chapter(_ num: Int) -> JingjiangChapter? {
        chapters.first { $0.num == num }
    }

    /// Whether a chapter is locked behind Pro. Chapter 1 is always free.
    func isLocked(_ chapter: JingjiangChapter, isPro: Bool) -> Bool {
        if isPro { return false }
        return chapter.num > Self.freeChapterCount
    }
}
