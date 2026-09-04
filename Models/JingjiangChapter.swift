import Foundation

// MARK: - 道德经精讲 (Tao Te Ching · In-Depth Commentary)
//
// Content source: bundled `jingjiang.json` (Resources/jingjiang.json).
// The text is original commentary in the "thinking-partner voice" (思考伙伴腔).
// All chapter content is original; Wang Bi verse text is public domain.
//
// Schema is read by `JingjiangService.loadAll()` at app start and cached.

struct JingjiangBundle: Codable {
    let version: Int
    let source: String
    let chapters: [JingjiangChapter]
}

struct JingjiangChapter: Codable, Identifiable {
    let num: Int
    let slug: String

    let title_cn: String
    let title_en: String
    let original_cn: String
    let original_en: String
    let tongshi_cn: String
    let tongshi_en: String
    let counter_cn: String
    let counter_en: String
    let scene_cn: String
    let scene_en: String
    let tension_cn: String
    let tension_en: String
    let action_cn: String
    let action_en: String

    var id: Int { num }

    /// Localized title based on the current app language.
    /// `AppState.currentLocaleId` is `@MainActor` static; bridge via `nonisolated(unsafe)`
    /// because the locale is read once at app start and never mutated after — safe to read off-main.
    @MainActor
    private var localeId: String { AppState.currentLocaleId }

    @MainActor
    var localizedTitle: String {
        AppState.currentLocaleId == "zh-Hans" ? title_cn : title_en
    }

    @MainActor
    var localizedOriginal: String {
        AppState.currentLocaleId == "zh-Hans" ? original_cn : original_en
    }

    @MainActor
    var localizedTongshi: String {
        AppState.currentLocaleId == "zh-Hans" ? tongshi_cn : tongshi_en
    }

    @MainActor
    var localizedCounter: String {
        AppState.currentLocaleId == "zh-Hans" ? counter_cn : counter_en
    }

    @MainActor
    var localizedScene: String {
        AppState.currentLocaleId == "zh-Hans" ? scene_cn : scene_en
    }

    @MainActor
    var localizedTension: String {
        AppState.currentLocaleId == "zh-Hans" ? tension_cn : tension_en
    }

    @MainActor
    var localizedAction: String {
        AppState.currentLocaleId == "zh-Hans" ? action_cn : action_en
    }

    /// Audio file name for the localized 通释 (TTS narration).
    /// `nil` if the audio hasn't been generated yet.
    @MainActor
    var audioFileName: String? {
        let lang = AppState.currentLocaleId == "zh-Hans" ? "cn" : "en"
        return "jingjiang_audio/\(slug)_\(lang).mp3"
    }
}
