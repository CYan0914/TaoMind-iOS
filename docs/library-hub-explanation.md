# Library Hub · Explanation

3 个关键设计决策,讲为什么这样、不那样。

---

## 1. 为什么从 194 章平铺改成 3 入口卡 hub

### 问题

build 47 之前,Library tab 是一整页 194 行的 List(81 道德经 + 32 金刚经 + 81 精讲 = 194 个 `Section > Row`)。用户反馈「列表太长了」—— 不是因为内容多(经藏就是这么多),而是因为:

1. **没有视觉分组边界**:`Section` 头只是 1 行 `Text`,滚动到中间(比如第 60 行)看不出来是道德经还是金刚经
2. **免费/付费边界被埋**:前 5 章免费 / 第 6 章起锁,这个分界点用户必须滚到第 6 行才知道
3. **精讲没有"准备感"**:81 章全展开时,精讲跟原文混在一起,Pro 用户根本不会觉得精讲是值得单独探索的内容;免费用户看到一堆锁图标直接关掉

### 方案

3 入口卡 = 3 个独立可探索的领域:

```
┌─────────────────────────────────────┐
│ 📕 道德经               81 章 · 原文 → │
│    原文                                 │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 💎 金刚经               32 章 · 原文 → │
│    原文                                 │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 📖 道德经·精讲  PRO     81 章 · 深度通释 → │
│    深度通释                             │
└─────────────────────────────────────┘
```

- **3 个独立认知单元** vs 194 行流水
- **每张卡能容纳 1 个元信息**:icon / 计数 / 副标(原文/深度)/ Pro 标
- **点进去才有 paywall**:免费用户的「锁」心理负担只出现在主动点开精讲卡时,不会一打开 Library 就被一堆锁图标劝退

### Trade-off

- ❌ 少 1 层 navigation:用户必须多点 1 次才能看具体章节
- ✅ 但配合「试读免费」策略,这个 1-click 成本可以忽略(原文前 5 章全开)
- ❌ Hub 本身不能滚动浏览原文,用户必须先选 1 个源 → 必须知道两个源都叫"原文"
- ✅ 「原文」+「深度通释」是 2 个明确副标,选哪个一目了然

### 替代方案

考虑过 TabView(道德经 / 金刚经 / 精讲 三个 tab)—— 但 iOS 标准 tab 是 5 个,只放 3 个有点浪费;加 "返回 Library" 入口又破坏 tab 的"平行"语义。最终选 hub 模式(更接近 App Store 的"Games / Apps / Updates"分类卡)。

---

## 2. 为什么按 `display_order` 升序排序,不用章节号字符串

### 问题

build 47 的金刚经 list 出现 1, 4, 7 章排在 32 章后面。原因:

旧代码 `LibraryView.diamondEntries` 只 `.filter` 不过 `.sorted`,完全按后端下发的 JSON 数组顺序展示。**后端把章节按"主题"分组(序分 / 般若 / 方便等)排,不是按章号排**。

修法的两种选择:

| 排序键 | 优劣 |
|---|---|
| `chapter` 字符串 | 「第 1 章」「第 10 章」「第 11 章」「第 2 章」按 UTF-8 字典序排 → 错位 |
| `verse_text` 长度 | 后端可能调文案 → 长度变化 → 顺序漂移 |
| `display_order: Int` | ✅ 后端定义,稳定,单调递增 |

### 关键代码

```swift
private var diamondEntries: [LibraryEntry] {
    entries
        .filter { $0.source == "Diamond Sutra" }
        .sorted { $0.display_order < $1.display_order }
}
```

`display_order` 是后端 `LibraryEntry` 字段,定义为"展示顺序 1-based 单调递增"。`id: Int { display_order }` 直接用做 SwiftUI `Identifiable` 的 id —— 保证 ForEach 稳定。

### 契约

后端必须保证:
- 每个 source 内的 `display_order` 唯一
- 1-based 单调递增
- 不会跳跃(不存在的章节不占 display_order)

违反契约会导致 list 出现重复或漏章节。前端不做兜底(本机版本,改后端重新发版即可)。

### 同样道理,精讲按 `JingjiangChapter.num` 排序

`JingjiangService.chapters` 来自 bundle JSON,数组顺序就是 num 升序,所以不显式 `.sorted`。`JingjiangChapter.id: Int { num }` 同样以 num 为 id,稳定。

---

## 3. 为什么在 `TaoMindApp.init()` 预热 jingjiang

### 问题

build 48 引入 hub 后,首次打开 Library tab 的用户看到 3 张卡先变 2 张再变 3 张 —— 闪烁。

原因:

```swift
.task {
    jingjiang.load()   // 同步,但在 .task 里
    await load()       // 异步,网络
}
```

- `LibraryView.body` 第一次 evaluate 时,`jingjiang.chapters` 还是空(因为 `JingjiangService.load()` 还没跑)
- `hubItems` 里的 `if !jingjiang.chapters.isEmpty` 过滤掉精讲卡
- 渲染 2 张卡
- `.task` 开始 → `jingjiang.load()` 同步从 bundle 读 JSON → `@Published chapters` 更新 → body 重新 evaluate → 3 张卡

### 方案

[TaoMind-iOS/TaoMindApp.swift#L19-L22](TaoMind-iOS/TaoMindApp.swift#L19-L22):

```swift
init() {
    SubscriptionManager.configure()
    Self.configureGoogleSignIn()
    JingjiangService.shared.load()  // ← 加这行
}
```

`load()` 是同步的(1.5MB JSON,实测 < 10ms),挪到 `init()` 不影响启动速度。app 启动后 `JingjiangService.shared.chapters` 就已 populated,首次打开 Library 直接 3 张卡全显。

### 跟注释对齐

`JingjiangService.load()` 的注释其实早就写明「Eager load (call from TaoMindApp init for first-paint perf)」—— 这是 build 47 写代码时漏掉的 wiring,build 48 引入 hub 后变成可见 bug,build 49 补上。

### Trade-off

- ❌ App 启动多 ~10ms(实测,在 iPhone 12 上 bundle JSON decode 大约 5-8ms)
- ❌ 不在 Library tab 启动 app 也加载(浪费内存 1.5MB)
- ✅ 修闪烁,UX 干净

`JingjiangService` 是 `@MainActor` 单例,只能 main thread 调。`TaoMindApp.init()` 已经在 main thread,没问题。

### 替代方案

考虑过把 `JingjiangService.load()` 留在 `LibraryView.task` 但加个"骨架屏"占位(loading card)。最终决定预热,因为:
- 1.5MB 加载可忽略
- 启动时预热让 PracticeView 等其他 tab 引用 `jingjiang` 时也是 ready 状态
- 不需要新增 UI state(loading / loaded)

---

## 关联决策

- **精讲 Pro 门控**:`JingjiangService.freeChapterCount = 3` —— build 47 决策(从 1 涨到 3,扩大 funnel)
- **原文 Pro 门控**:`LibrarySourceView.freeTasteCount = 5` —— 沿用 build 38 老值
- **精讲 81 章扩到全本**:build 47 决策(从 36 章扩),解释见 `TaoMind_iOS_完整流程总结.md` build 47 章节
- **TTS 音频暂不做**:用户 build 47 决策(「先文字版本,看看效果」),所以 `JingjiangAudioPlayer` 还是 stub
