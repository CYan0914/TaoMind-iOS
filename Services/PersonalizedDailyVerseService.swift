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

    // MARK: - Cache（1.8.1:一天一条「日期实体」,语言槽住在实体内部）

    /// 语言无关的实体 key。**切语言不换 key** —— 这是 1.8.0 切语言换章的根修:
    /// 老 key 带 language 后缀,切语言必然 cache miss,于是重挑一次经(而 prompt
    /// 里的 Recently shown 又刚把上一章写进去,逼它必须换,金刚经就变道德经了)。
    private func entityKey(date: Date = Date()) -> String {
        let userId = AuthService.shared.user.map { "u\($0.id)" } ?? "anon"
        return "\(Self.personalizedCachePrefix).\(userId).\(dayString(date))"
    }

    /// 1.8.0 及更早的 key(带 language 后缀)。**只读**,用于升级当天把老数据
    /// 搬进实体;不再往这里写。
    private func legacyCacheKey(language: String, date: Date = Date()) -> String {
        "\(entityKey(date: date)).\(language)"
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func decodeEntity(key: String) -> PersonalizedDailyVerse? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersonalizedDailyVerse.self, from: data)
    }

    private func loadEntity(date: Date = Date()) -> PersonalizedDailyVerse? {
        decodeEntity(key: entityKey(date: date))
    }

    private func saveEntity(_ env: PersonalizedDailyVerse) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(env) {
            UserDefaults.standard.set(data, forKey: entityKey())
        }
    }

    /// 同步读今日缓存(给 NotificationService 用,不阻塞)。
    /// 签名与老 key 字符串保持不变 → NotificationService 零改动。
    func cachedForToday(language: String) -> DailyVerse? {
        let isEnglish = language != "zh"
        if let env = loadEntity(),
           let v = slot(of: env, isEnglish: isEnglish), hasContent(v) {
            return v
        }
        // 升级后今天还没走过 fetch(实体尚未生成)→ 老 key 只读兜底
        if let env = decodeEntity(key: legacyCacheKey(language: language)),
           let v = env.verse, hasContent(v) {
            return v
        }
        return nil
    }

    private func slot(of env: PersonalizedDailyVerse, isEnglish: Bool) -> DailyVerse? {
        isEnglish ? env.en : env.verse
    }

    /// 槽位是否真有内容。空壳 verse(主字段与 `_en` 都为空)不算命中 ——
    /// 否则切语言会拿到一份空白,等于 1.8.0 的「经文消失」。
    private func hasContent(_ v: DailyVerse) -> Bool {
        !v.verse_text.isEmpty || !(v.verse_text_en ?? "").isEmpty
    }

    /// 老数据形态判定:主字段有内容 = 中文形态;只有 `_en` 有内容 = 英文形态。
    private func isChineseForm(_ v: DailyVerse) -> Bool {
        !v.verse_text.isEmpty || !v.chapter.isEmpty || !v.reflection.isEmpty
    }

    private func isEnglishForm(_ v: DailyVerse) -> Bool {
        !(v.verse_text_en ?? "").isEmpty
            || !(v.chapter_en ?? "").isEmpty
            || !(v.reflection_en ?? "").isEmpty
    }

    /// 把 1.8.0 的两条老 key(`.zh` / `.en`)搬进一个语言无关的实体。
    ///
    /// 按**内容**判槽位,不看 key 后缀 —— 老代码在中文模式下也可能产出纯英文
    /// 形态(`parseToVerse` 的最终 fallback 就是),后缀不可信。
    private func migratedEntity() -> PersonalizedDailyVerse? {
        let legacy = [decodeEntity(key: legacyCacheKey(language: "zh")),
                      decodeEntity(key: legacyCacheKey(language: "en"))].compactMap { $0 }
        guard !legacy.isEmpty else { return nil }

        var zhSlot: DailyVerse?
        var enSlot: DailyVerse?
        for env in legacy {
            guard let v = env.verse else { continue }
            if isChineseForm(v) {
                if zhSlot == nil { zhSlot = v }
            } else if isEnglishForm(v) {
                if enSlot == nil { enSlot = v }
            }
        }
        guard zhSlot != nil || enSlot != nil else { return nil }

        return PersonalizedDailyVerse(
            verse: zhSlot,
            en: enSlot,
            generatedAt: legacy.map(\.generatedAt).max() ?? Date(),
            moodRaw: legacy.first?.moodRaw,
            userIntent: legacy.first?.userIntent
        )
    }

    /// 生成某一语言槽时用来「锁章」的参照物 —— 取自**另一槽**。
    struct VerseLock {
        let source: String
        /// 目标语言下的章名无从得知,所以这里存的是另一槽的章名(可能是中文)。
        let chapter: String
        let referenceText: String
    }

    /// 从"另一个槽"取锁。另一个槽为空 → nil,回到自由选章(当天第一次生成)。
    private func reference(from env: PersonalizedDailyVerse, targetIsEnglish: Bool) -> VerseLock? {
        guard let o = targetIsEnglish ? env.verse : env.en else { return nil }
        let chapter = ((o.chapter_en?.isEmpty == false) ? o.chapter_en! : o.chapter)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let text = ((o.verse_text_en?.isEmpty == false) ? o.verse_text_en! : o.verse_text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chapter.isEmpty || !text.isEmpty else { return nil }
        return VerseLock(
            source: o.source,
            chapter: chapter,
            referenceText: String(text.prefix(200))
        )
    }

    private func recordShown(verse: DailyVerse) {
        // 去重键取 `chapter_en ?? chapter`：英文模式的 verse 主字段留空
        // （主字段是中文槽位，见 bilingual()），章节号只在 `_en` 里。
        let chapter = (verse.chapter_en?.isEmpty == false) ? verse.chapter_en! : verse.chapter
        guard !chapter.isEmpty else { return }
        let entry = "\(verse.source) · \(chapter)"
        var arr = recentlyShown()
        // 同日同章不重复记。1.8.0 里每次 saveCache 都无条件 append,一天切几次
        // 语言就能把 14 条上限刷满,之后几天的选章被这条黑名单持续带偏。
        guard !arr.contains(entry) else { return }
        arr.append(entry)
        if arr.count > 14 { arr = Array(arr.suffix(14)) }
        UserDefaults.standard.set(arr, forKey: Self.recentlyShownKey)
    }

    private func recentlyShown() -> [String] {
        UserDefaults.standard.array(forKey: Self.recentlyShownKey) as? [String] ?? []
    }

    // MARK: - Fetch

    /// 取今日个性化 verse。**幂等**:目标语言槽已有内容就纯本地返回,不碰网络。
    /// 失败抛错让 caller 走 VerseFallback。
    func fetchTodaysPersonalizedVerse(
        mood: Mood?,
        recentReflections: [String],
        userIntent: String?,
        language: String
    ) async throws -> DailyVerse {
        let targetIsEnglish = language != "zh"

        // 1) 今日实体:新 key → 老 key 迁移 → 空实体
        let existing = loadEntity()
        let migrated = existing == nil ? migratedEntity() : nil
        var env = existing ?? migrated
            ?? PersonalizedDailyVerse(verse: nil, en: nil, generatedAt: Date(), moodRaw: nil, userIntent: nil)

        // 2) 目标槽已有内容 → 本地读返回。切语言的常见路径走这里:
        //    0 网络、0 LLM 额度、章节绝对不变。
        if let hit = slot(of: env, isEnglish: targetIsEnglish), hasContent(hit) {
            if migrated != nil { saveEntity(env) }   // 迁移结果落地,免得下次再搬
            return hit
        }

        // 3) 目标槽为空(典型:老用户第一次切到另一种语言)→ 补一次,
        //    用另一槽锁死 source + chapter,强制同一章。
        let lock = reference(from: env, targetIsEnglish: targetIsEnglish)
        let fresh = try await callLLM(
            mood: mood,
            recentReflections: recentReflections,
            userIntent: userIntent,
            language: language,
            lock: lock
        )
        env = env.writing(fresh, isEnglish: targetIsEnglish)
        env.moodRaw = mood?.apiValue ?? env.moodRaw
        env.userIntent = userIntent ?? env.userIntent
        saveEntity(env)
        // 只在真正新生成时记去重(本地读那条路径绝不记)
        recordShown(verse: fresh)
        return fresh
    }

    // MARK: - LLM call + parse

    private func callLLM(
        mood: Mood?,
        recentReflections: [String],
        userIntent: String?,
        language: String,
        lock: VerseLock?
    ) async throws -> DailyVerse {
        let prompt = buildQuestionPrompt(
            mood: mood,
            recentReflections: recentReflections,
            userIntent: userIntent,
            language: language,
            lock: lock
        )
        let token = AuthService.shared.token

        // 1st: 新 scenario_type(后端可能 400)
        do {
            return try await callSeekWisdom(
                question: prompt,
                scenarioType: "personalized_daily_verse",
                language: language,
                token: token,
                lock: lock
            )
        } catch {
            // 2nd: 降级到 "personal" (最可能产生 verse 内容的现有 scenario_type)
            return try await callSeekWisdom(
                question: prompt,
                scenarioType: "personal",
                language: language,
                token: token,
                lock: lock
            )
        }
    }

    private func callSeekWisdom(
        question: String,
        scenarioType: String,
        language: String,
        token: String?,
        lock: VerseLock?
    ) async throws -> DailyVerse {
        let client = APIClient(baseURL: apiBaseURL)
        let resp = try await client.seekWisdom(
            question: question,
            scenarioType: scenarioType,
            temperature: 0.7,
            language: language,
            authToken: token
        )
        return parseToVerse(resp, language: language, lock: lock)
    }

    /// 4 层 fallback:JSON shape → markdown fence → WisdomResponse 字段直读 → VerseFallback
    ///
    /// `language` 决定 LLM 输出的语言（prompt 里已带 `Language: en|zh`），
    /// 而这个语种的内容必须同时写进 `_en` 三列 —— 否则 `DailyVerse.localized*`
    /// 在英文模式下读到空的 `_en` 会回落中文，个性化经文就永远是中文的。
    private func parseToVerse(_ resp: WisdomResponse, language: String, lock: VerseLock?) -> DailyVerse {
        // 1) LLM 期望输出 JSON shape;在 passage 里取
        if let v = parseJSONShape(in: resp.passage, language: language, lock: lock) { return v }
        // 2) regex 提取 ```json ... ``` 块
        if let v = parseMarkdownFence(in: resp.passage, language: language, lock: lock) { return v }
        // 3) WisdomResponse 直读:passage 当 verse_text,reflection 当 reflection。
        //    ⚠️ 这层拿不到章名 —— 若手上有锁,宁可用锁也不要让卡片退化成无章可显。
        if !resp.passage.isEmpty {
            return bilingual(
                source: lock?.source ?? "Tao Te Ching",
                chapter: lock?.chapter ?? "",
                text: stripMarkdown(stripEmoji(resp.passage)),
                reflection: stripMarkdown(stripEmoji(resp.reflection)),
                language: language
            )
        }
        // 4) Final fallback
        let fb = VerseFallback.verseForToday()
        // VerseFallback 的文案本身是英文的 → 只进 `_en` 三列，主字段留空，
        // 避免英文文本滞留在中文界面（串语言）。
        //
        // 1.8.0 这里曾少写 `chapter_en`（只给「中文槽位留空」的形态，章名却丢在
        // 主字段），而当时 localized() 的中文分支又不检查空 → 中文界面整卡空白。
        // 现在 localized() 两个方向都回落，这里也统一走 bilingual() 保持形态一致。
        return bilingual(
            source: fb.source,
            chapter: fb.chapter,
            text: fb.text,
            reflection: fb.reflection,
            language: "en"
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

    private func parseJSONShape(in text: String, language: String, lock: VerseLock?) -> DailyVerse? {
        // 直 JSON
        if let data = text.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
           let passage = parsed.passage, !passage.isEmpty {
            return verseFromParsed(parsed, fallbackPassage: passage, language: language, lock: lock)
        }
        return nil
    }

    private func parseMarkdownFence(in text: String, language: String, lock: VerseLock?) -> DailyVerse? {
        // ```json ... ``` block
        let pattern = "```(?:json)?\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let jsonStr = String(text[r])
        guard let data = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedJSON.self, from: data),
              let passage = parsed.passage, !passage.isEmpty else { return nil }
        return verseFromParsed(parsed, fallbackPassage: passage, language: language, lock: lock)
    }

    private func verseFromParsed(_ parsed: ParsedJSON, fallbackPassage: String, language: String, lock: VerseLock?) -> DailyVerse {
        // 有锁时**无条件用锁**:模型偶尔会无视 prompt 自选一章,那正是
        // 「同一天中英不是同一章」的复发路径,这里从数据上兜死。
        let source = lock?.source
            ?? ((parsed.source?.isEmpty == false) ? parsed.source! : "Tao Te Ching")
        let chapter = lock?.chapter ?? (parsed.chapter ?? "")
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
        language: String,
        lock: VerseLock?
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

        if let lock = lock {
            // 补另一语言槽:章节已经被另一槽钉死,模型只负责把这一章写成目标语言。
            //
            // 注意 Recently shown 那行必须**显式豁免**、且和 Required verse 挨着:
            // 只写 "Required verse: X" 而留着 "do NOT repeat" 会让模型收到两条
            // 冲突指令,而它偏向更靠后的否定指令 → 又把章换掉(这正是 1.8.0 的 bug)。
            // source/chapter 也已从严格 JSON schema 里挪走,模型没有可填的章名槽位。
            return """
            Daily verse request — TRANSLATION TASK, NOT A SELECTION TASK.
            Mood: \(moodStr)
            Life focus: \(focusStr)
            Recent reflections (last 7 days):
            \(reflectionLines)
            Recently shown (context only — IGNORE for this request): \(shownLines.isEmpty ? "(none)" : shownLines)
            Date: \(dateStr)
            Language: \(langStr)

            Required verse: \(lock.source) · \(lock.chapter)
            This verse is already fixed for today. Do NOT choose a different chapter.
            The recently-shown list above does NOT apply to this request.
            Write the passage and the reflection of the required verse in \(langStr).
            The text below is a meaning anchor only — do not copy it verbatim, do not echo its language:
            \(lock.referenceText)

            Output JSON exactly:
            {"passage": "<required verse's text in \(langStr), 200 chars max>", "reflection": "<2-line reflection in \(langStr), 200 chars max>"}
            No prose outside JSON. No markdown. No emoji.
            """
        }

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
