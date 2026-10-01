import Foundation

// MARK: - Personalized Daily Verse Service (build 50: 情绪化每日经文)
//
// 设计要点：
// 1. 复用 `/seek-wisdom` 端点(主后端) → 不新搭后端,不动主后端代码
// 2. 每日 1 个 user × 1 LLM call;缓存命中当日(per userId + yyyyMMdd + language)绝不重 LLM
// 3. Mood 中途切换不重 LLM(省 50/天 Pro 额度)
// 4. Pro 永远过;Free 仅 Day 1-3 过(trial);Day 4 起非 Pro 走 fallback + upgrade banner
// 5. 解析 4 层 fallback:JSON → regex 提取 markdown fence → WisdomResponse 字段 → VerseFallback
// 6. scenario_type 优先 "personalized_daily_verse"(新值),400 时 retry "personal"
//
// 调用契约：
//   - 入参: mood(可空,空时 LLM 按"无特定状态"选 verse) + recentReflections + userIntent + language
//   - 出参: DailyVerse(已 cache + 写入)或 throw 让 caller 走 VerseFallback
//   - 缓存同步读 (cachedForToday) 给 NotificationService 8am 推送用,非阻塞

@MainActor
struct PersonalizedDailyVerseService {
    private let apiBaseURL = "https://taomindapp.com"

    // MARK: - Keys

    private static let installDateKey = "installDate"
    private static let todaysMoodKey = "todaysMood"
    private static let personalizedCachePrefix = "personalizedVerse"
    private static let recentlyShownKey = "personalizedVerse.recentlyShown"

    // MARK: - Free trial

    /// 新装后前 3 个日历日免费体验 Day 1, 2, 3
    static func isInFreeTrial(now: Date = Date()) -> Bool {
        let install = UserDefaults.standard.object(forKey: installDateKey) as? Date ?? Date()
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: install),
            to: cal.startOfDay(for: now)).day ?? 0
        return days >= 0 && days < 3
    }

    /// 是否在 Pro 或 trial 窗口内(可享受 personalized verse)
    func isEligible() -> Bool {
        guard AuthService.shared.isSignedIn else { return false }
        return SubscriptionManager.shared.isPro || Self.isInFreeTrial()
    }

    // MARK: - Mood (当日)

    func saveTodaysMood(_ mood: Mood?) {
        let key = Self.todaysMoodKey
        if let mood = mood {
            UserDefaults.standard.set(mood.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func todaysMood() -> Mood? {
        guard let raw = UserDefaults.standard.string(forKey: Self.todaysMoodKey) else { return nil }
        return Mood(rawValue: raw)
    }

    /// 跨午夜时清空 mood cache(老 entry 已不再适用)。
    /// 在 `loadDailyVerse` 调一次。
    func clearStaleMoodIfNewDay(now: Date = Date()) {
        let today = dayString(now)
        let lastSeen = UserDefaults.standard.string(forKey: "todaysMood.lastSeenDay")
        if lastSeen != today {
            UserDefaults.standard.removeObject(forKey: Self.todaysMoodKey)
            UserDefaults.standard.set(today, forKey: "todaysMood.lastSeenDay")
        }
    }

    // MARK: - Cache

    private func cacheKey(language: String, date: Date = Date()) -> String {
        let userId = AuthService.shared.user.map { "u\($0.id)" } ?? "anon"
        return "\(Self.personalizedCachePrefix).\(userId).\(dayString(date)).\(language)"
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// 同步读今日缓存(给 NotificationService 用,不阻塞)
    func cachedForToday(language: String) -> DailyVerse? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(language: language)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let env = try? decoder.decode(PersonalizedDailyVerse.self, from: data) else { return nil }
        return env.verse
    }

    private func saveCache(_ verse: DailyVerse, mood: Mood?, userIntent: String?, language: String) {
        let env = PersonalizedDailyVerse(
            verse: verse,
            generatedAt: Date(),
            moodRaw: mood?.apiValue,
            userIntent: userIntent
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(env) {
            UserDefaults.standard.set(data, forKey: cacheKey(language: language))
        }
        // 顺便记入"最近展示过的 chapter"列表,服务下次的 LLM prompt 去重
        recordShown(verse: verse)
    }

    private func recordShown(verse: DailyVerse) {
        // 去重键取 `chapter_en ?? chapter`：英文模式的 verse 主字段留空
        // （主字段是中文槽位，见 bilingual()），章节号只在 `_en` 里。
        let chapter = verse.chapter_en ?? verse.chapter
        let entry = "\(verse.source) · \(chapter)"
        var arr = UserDefaults.standard.array(forKey: Self.recentlyShownKey) as? [String] ?? []
        arr.append(entry)
        if arr.count > 14 { arr = Array(arr.suffix(14)) }
        UserDefaults.standard.set(arr, forKey: Self.recentlyShownKey)
    }

    private func recentlyShown() -> [String] {
        UserDefaults.standard.array(forKey: Self.recentlyShownKey) as? [String] ?? []
    }

    // MARK: - Fetch

    /// 取今日个性化 verse(已缓存则不重 LLM)。失败抛错让 caller 走 VerseFallback。
    func fetchTodaysPersonalizedVerse(
        mood: Mood?,
        recentReflections: [String],
        userIntent: String?,
        language: String
    ) async throws -> DailyVerse {
        if let cached = cachedForToday(language: language) {
            return cached
        }
        let verse = try await callLLM(
            mood: mood,
            recentReflections: recentReflections,
            userIntent: userIntent,
            language: language
        )
        saveCache(verse, mood: mood, userIntent: userIntent, language: language)
        return verse
    }

    // MARK: - LLM call + parse

    private func callLLM(
        mood: Mood?,
        recentReflections: [String],
        userIntent: String?,
        language: String
    ) async throws -> DailyVerse {
        let prompt = buildQuestionPrompt(
            mood: mood,
            recentReflections: recentReflections,
            userIntent: userIntent,
            language: language
        )
        let token = AuthService.shared.token

        // 1st: 新 scenario_type(后端可能 400)
        do {
            return try await callSeekWisdom(
                question: prompt,
                scenarioType: "personalized_daily_verse",
                language: language,
                token: token
            )
        } catch {
            // 2nd: 降级到 "personal" (最可能产生 verse 内容的现有 scenario_type)
            return try await callSeekWisdom(
                question: prompt,
                scenarioType: "personal",
                language: language,
                token: token
            )
        }
    }

    private func callSeekWisdom(
        question: String,
        scenarioType: String,
        language: String,
        token: String?
    ) async throws -> DailyVerse {
        let client = APIClient(baseURL: apiBaseURL)
        let resp = try await client.seekWisdom(
            question: question,
            scenarioType: scenarioType,
            temperature: 0.7,
            language: language,
            authToken: token
        )
        return parseToVerse(resp, language: language)
    }

    /// 4 层 fallback:JSON shape → markdown fence → WisdomResponse 字段直读 → VerseFallback
    ///
    /// `language` 决定 LLM 输出的语言（prompt 里已带 `Language: en|zh`），
    /// 而这个语种的内容必须同时写进 `_en` 三列 —— 否则 `DailyVerse.localized*`
    /// 在英文模式下读到空的 `_en` 会回落中文，个性化经文就永远是中文的。
    private func parseToVerse(_ resp: WisdomResponse, language: String) -> DailyVerse {
        // 1) LLM 期望输出 JSON shape;在 passage 里取
        if let v = parseJSONShape(in: resp.passage, language: language) { return v }
        // 2) regex 提取 ```json ... ``` 块
        if let v = parseMarkdownFence(in: resp.passage, language: language) { return v }
        // 3) WisdomResponse 直读:passage 当 verse_text,reflection 当 reflection
        if !resp.passage.isEmpty {
            return bilingual(
                source: "Tao Te Ching",
                chapter: "",
                text: stripMarkdown(stripEmoji(resp.passage)),
                reflection: stripMarkdown(stripEmoji(resp.reflection)),
                language: language
            )
        }
        // 4) Final fallback
        let fb = VerseFallback.verseForToday()
        // VerseFallback 的文案本身是英文的 → 只进 `_en` 三列，主字段留空。
        // 中文模式下 localized() 读主字段拿到空串会回落 `_en`（英文），
        // 至少不会出现「英文模式的文本滞留在中文界面」这种串语言。
        return DailyVerse(
            source: fb.source,
            chapter: "",
            verse_text: "",
            reflection: "",
            chapter_en: fb.chapter,
            verse_text_en: fb.text,
            reflection_en: fb.reflection
        )
    }

    /// 把一份内容按当前语言落到 `DailyVerse` 的两个语言槽位。
    ///
    /// **英文内容只进 `_en` 三列，绝不写主字段。** 主字段是「中文原文」槽位：
    /// `DailyVerse.localized()` 在中文模式下直接读主字段，如果英文模式把英文
    /// 灌进主字段，用户从英文切回中文时就会看到一段滞留的英文（build 66 的
    /// 线上 bug）。留空时 `localized()` 的 `e.isEmpty ? zh : e` 会回落英文，
    /// 至少不会串语言。
    ///
    /// `recordShown()` 去重仍需要 chapter 有值，所以这里单给 `chapter` 兜底。
    private func bilingual(
        source: String,
        chapter: String,
        text: String,
        reflection: String,
        language: String
    ) -> DailyVerse {
        let isEnglish = language != "zh"
        // 中文内容进主字段；英文内容只进 `_en`。
        // 去重键 `source · chapter` 需要 chapter 非空 → 英文模式也回填 chapter。
        return DailyVerse(
            source: source,
            chapter: isEnglish ? "" : chapter,
            verse_text: isEnglish ? "" : text,
            reflection: isEnglish ? "" : reflection,
            chapter_en: isEnglish ? chapter : nil,
            verse_text_en: isEnglish ? text : nil,
            reflection_en: isEnglish ? reflection : nil
        )
    }

    private struct ParsedJSON: Decodable {
        let source: String?
        let chapter: String?
        let passage: String?
        let reflection: String?
    }

    private func parseJSONShape(in text: String, language: String) -> DailyVerse? {
        // 直 JSON
        if let data = text.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
           let passage = parsed.passage, !passage.isEmpty {
            return verseFromParsed(parsed, fallbackPassage: passage, language: language)
        }
        return nil
    }

    private func parseMarkdownFence(in text: String, language: String) -> DailyVerse? {
        // ```json ... ``` block
        let pattern = "```(?:json)?\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let jsonStr = String(text[r])
        guard let data = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
              let passage = parsed.passage, !passage.isEmpty else { return nil }
        return verseFromParsed(parsed, fallbackPassage: passage, language: language)
    }

    private func verseFromParsed(_ parsed: ParsedJSON, fallbackPassage: String, language: String) -> DailyVerse {
        let source = (parsed.source?.isEmpty == false) ? parsed.source! : "Tao Te Ching"
        let chapter = parsed.chapter ?? ""
        let passage = cleanText(fallbackPassage, max: 200)
        let reflection = cleanText(parsed.reflection ?? "", max: 200)
        return bilingual(
            source: source,
            chapter: chapter,
            text: passage,
            reflection: reflection,
            language: language
        )
    }

    // MARK: - Text cleaning

    /// 截断 + 剥 markdown 强调 + 剥 emoji
    private func cleanText(_ raw: String, max: Int) -> String {
        let stripped = stripMarkdown(stripEmoji(raw)).trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.count <= max { return stripped }
        // 词边界截断
        let truncated = String(stripped.prefix(max))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "…"
        }
        return truncated + "…"
    }

    private func stripMarkdown(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "")
         .replacingOccurrences(of: "__", with: "")
         .replacingOccurrences(of: "*", with: "")
         .replacingOccurrences(of: "_", with: "")
    }

    /// 极简 emoji stripper:把常见 emoji unicode 范围清掉(用户不期望 verse 里出 emoji)
    private func stripEmoji(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            if scalar.properties.isEmoji { continue }
            out.unicodeScalars.append(scalar)
        }
        return out
    }

    // MARK: - Prompt

    private func buildQuestionPrompt(
        mood: Mood?,
        recentReflections: [String],
        userIntent: String?,
        language: String
    ) -> String {
        let moodStr = mood?.apiValue ?? "none"
        let focusStr = (userIntent?.isEmpty == false) ? userIntent! : "not specified"
        let dateStr = dayString(Date())
        let langStr = language == "zh" ? "zh" : "en"

        let reflectionLines: String
        if recentReflections.isEmpty {
            reflectionLines = "  (none yet)"
        } else {
            reflectionLines = recentReflections.prefix(7)
                .enumerated()
                .map { "  - \($0.offset + 1)d ago: \"\(trimTo($0.element, 200))\"" }
                .joined(separator: "\n")
        }
        let shownLines = recentlyShown().suffix(7).joined(separator: ", ")

        return """
        Daily verse request.
        Mood: \(moodStr)
        Life focus: \(focusStr)
        Recent reflections (last 7 days):
        \(reflectionLines)
        Recently shown (do NOT repeat): \(shownLines.isEmpty ? "(none)" : shownLines)
        Date: \(dateStr)
        Language: \(langStr)

        Output JSON exactly:
        {"source": "Tao Te Ching" or "Diamond Sutra", "chapter": "Chapter N", "passage": "<verse text, 200 chars max>", "reflection": "<2-line reflection, 200 chars max>"}
        No prose outside JSON. No markdown. No emoji.
        """
    }

    private func trimTo(_ s: String, _ max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }
}
