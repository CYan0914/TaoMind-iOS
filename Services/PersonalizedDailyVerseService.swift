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
        let entry = "\(verse.source) · \(verse.chapter)"
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
        return parseToVerse(resp)
    }

    /// 4 层 fallback:JSON shape → markdown fence → WisdomResponse 字段直读 → VerseFallback
    private func parseToVerse(_ resp: WisdomResponse) -> DailyVerse {
        // 1) LLM 期望输出 JSON shape;在 passage 里取
        if let v = parseJSONShape(in: resp.passage) { return v }
        // 2) regex 提取 ```json ... ``` 块
        if let v = parseMarkdownFence(in: resp.passage) { return v }
        // 3) WisdomResponse 直读:passage 当 verse_text,reflection 当 reflection
        if !resp.passage.isEmpty {
            return DailyVerse(
                source: "Tao Te Ching",
                chapter: "",
                verse_text: stripMarkdown(stripEmoji(resp.passage)),
                reflection: stripMarkdown(stripEmoji(resp.reflection))
            )
        }
        // 4) Final fallback
        let fb = VerseFallback.verseForToday()
        return DailyVerse(
            source: fb.source,
            chapter: fb.chapter,
            verse_text: fb.text,
            reflection: fb.reflection
        )
    }

    private struct ParsedJSON: Decodable {
        let source: String?
        let chapter: String?
        let passage: String?
        let reflection: String?
    }

    private func parseJSONShape(in text: String) -> DailyVerse? {
        // 直 JSON
        if let data = text.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
           let passage = parsed.passage, !passage.isEmpty {
            return verseFromParsed(parsed, fallbackPassage: passage)
        }
        return nil
    }

    private func parseMarkdownFence(in text: String) -> DailyVerse? {
        // ```json ... ``` block
        let pattern = "```(?:json)?\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let jsonStr = String(text[r])
        guard let data = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
              let passage = parsed.passage, !passage.isEmpty else { return nil }
        return verseFromParsed(parsed, fallbackPassage: passage)
    }

    private func verseFromParsed(_ parsed: ParsedJSON, fallbackPassage: String) -> DailyVerse {
        let source = (parsed.source?.isEmpty == false) ? parsed.source! : "Tao Te Ching"
        let chapter = parsed.chapter ?? ""
        let passage = cleanText(fallbackPassage, max: 200)
        let reflection = cleanText(parsed.reflection ?? "", max: 200)
        return DailyVerse(
            source: source,
            chapter: chapter,
            verse_text: passage,
            reflection: reflection
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
