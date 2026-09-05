# Library Hub · Reference

build 48 起的「经藏」模块公共 surface。每个条目都对应到具体代码行,可直接定位。

---

## 公共视图(用户可见)

### `LibraryView` — 入口 hub
- 文件:[TaoMind-iOS/Views/LibraryView.swift#L10-L178](TaoMind-iOS/Views/LibraryView.swift#L10-L178)
- 角色:Library tab 根视图,3 张入口卡的 host
- 状态:
  - `entries: [LibraryEntry]` — 原文 entries(后端 fetch)
  - `isLoading: Bool` — 初次加载占位
  - `errorMessage: String?` — 网络错误
  - `jingjiang: JingjiangService` — 精讲本地状态
- 副作用:`.task` 触发 `jingjiang.load()` + `api.fetchLibrary()`
- 路由:基于 `LibraryDestination` 的 value-based `NavigationStack`
- 失败状态:展示 error 图标 + Retry 按钮

### `LibrarySourceView` — 原文列表(道德经/金刚经通用)
- 文件:[TaoMind-iOS/Views/LibrarySourceView.swift#L8-L82](TaoMind-iOS/Views/LibrarySourceView.swift#L8-L82)
- 签名:`init(title: String, source: String, entries: [LibraryEntry])`
- 行为:
  - 显示 `entries`(已按 display_order 升序排序)
  - 前 5 章免费(`freeTasteCount = 5`),后续走 paywall
  - 非 Pro + locked → `subscriptionManager.openPaywall(.libraryLocked)`
  - Pro → 全开
- 行 UI:章节标题 + 经文片段(2 行截断) + chevron/lock 图标

### `LibraryJingjiangView` — 精讲列表(81 章)
- 文件:[TaoMind-iOS/Views/LibraryJingjiangView.swift#L8-L83](TaoMind-iOS/Views/LibraryJingjiangView.swift#L8-L83)
- 签名:无参 `init()`
- 行为:
  - 读 `JingjiangService.shared.chapters`(本机 bundle)
  - 前 3 章免费(`JingjiangService.freeChapterCount = 3`),后续 paywall
  - 非 Pro + locked → `subscriptionManager.openPaywall(.jingjiangLocked)`
  - 行 UI:章节号 + 通释片段 + PRO 标(locked 时)

---

## 私有辅助类型

### `LibraryDestination` enum
- 文件:[TaoMind-iOS/Views/LibraryView.swift#L182-L186](TaoMind-iOS/Views/LibraryView.swift#L182-L186)
- 3 cases:`taoTeChing` / `diamondSutra` / `jingjiang`
- `Hashable`,用于 `NavigationLink(value:)` + `.navigationDestination(for:)`

### `LibraryHubItem` struct
- 文件:[TaoMind-iOS/Views/LibraryView.swift#L190-L198](TaoMind-iOS/Views/LibraryView.swift#L190-L198)
- 描述一张卡:`id` / `title` / `subtitle` / `countText` / `icon` / `requiresPro` / `destination`

### `LibraryHubCard` view
- 文件:[TaoMind-iOS/Views/LibraryView.swift#L202-L259](TaoMind-iOS/Views/LibraryView.swift#L202-L259)
- 单张卡 UI:左侧 48×48 铜金图标方块 + 标题/副标/计数 + 右侧 chevron

---

## 模型

### `LibraryEntry` — 后端原文条目
- 文件:[TaoMind-iOS/Models/Checkin.swift#L103-L112](TaoMind-iOS/Models/Checkin.swift#L103-L112)

| 字段 | 类型 | 含义 |
|---|---|---|
| `source` | `String` | `"Tao Te Ching"` / `"Diamond Sutra"` / 未来的其他源 |
| `chapter` | `String` | 章节标题(显示用,如 "第一章 道可道") |
| `verse_text` | `String` | 经文主体(显示用,2 行截断) |
| `commentary` | `String` | 简注(详情页用) |
| `reflection` | `String` | 反思提示(详情页用) |
| `display_order` | `Int` | **排序键** — 后端下发,升序展示 |
| `id` | `Int` | `= display_order`,SwiftUI `Identifiable` 要求 |

### `LibraryResponse` — API 响应
- 文件:[TaoMind-iOS/Models/Checkin.swift#L114-L117](TaoMind-iOS/Models/Checkin.swift#L114-L117)
- `entries: [LibraryEntry]` + `total: Int`(目前 UI 不用 `total`)

### `JingjiangChapter` — 精讲条目
- 文件:[TaoMind-iOS/Models/JingjiangChapter.swift#L17-L86](TaoMind-iOS/Models/JingjiangChapter.swift#L17-L86)
- 16 字段:`num` / `slug` / 双语 7 段内容(标题/原文/通释/反常识/场景/张力/行动)
- `id: Int { num }`,按 num 升序展示
- 7 个 `@MainActor` 本地化访问器(读 `AppState.currentLocaleId`)

### `JingjiangBundle` — bundle 顶层
- 文件:[TaoMind-iOS/Models/JingjiangChapter.swift#L11-L15](TaoMind-iOS/Models/JingjiangChapter.swift#L11-L15)
- `{ version, source, chapters: [JingjiangChapter] }`

---

## 服务

### `JingjiangService.shared`
- 文件:[TaoMind-iOS/Services/JingjiangService.swift](TaoMind-iOS/Services/JingjiangService.swift)
- `@MainActor` 单例
- `static let freeChapterCount = 3` — 精讲免费章节数
- `load()` — 同步从 bundle 读 `jingjiang.json`(~1.5MB),首次调用后 `isLoaded = true`
- `chapters: [JingjiangChapter]` — `@Published`,UI 监听
- `isLocked(_:isPro:)` — Pro 全开,非 Pro 仅 `num <= freeChapterCount` 解锁

### `APIClient.fetchLibrary()`
- 文件:[TaoMind-iOS/Services/APIClient.swift#L124](TaoMind-iOS/Services/APIClient.swift#L124)
- `GET /library`,30s timeout
- 携带登录态:服务端按 Pro 下发完整原文,免费用户前 5 章
- 返回 `LibraryResponse`

### `PaywallContext` — 付费墙场景
- 文件:[TaoMind-iOS/Services/SubscriptionManager.swift#L8-L13](TaoMind-iOS/Services/SubscriptionManager.swift#L8-L13)
- Library hub 用到的 cases:
  - `.libraryLocked` — 原文免费试读结束
  - `.jingjiangLocked` — 精讲试读结束

---

## i18n 字符串(Resources/{en,zh-Hans}.lproj/Localizable.strings)

| Key | en | zh-Hans | 用途 |
|---|---|---|---|
| `library_tao_te_ching` | `Tao Te Ching` | `《道德经》` | 道德经卡 + 详情标题 |
| `library_diamond_sutra` | `Diamond Sutra` | `《金刚经》` | 金刚经卡 + 详情标题 |
| `library_jingjiang` | `Tao Te Ching · In-Depth` | `道德经·精讲` | 精讲卡 + 详情标题 |
| `library_jingjiang_pro` | `PRO` | `PRO` | 精讲卡 / 锁行右侧 PRO 标 |
| `library_hub_original` | `Original verses` | `原文` | 道德经 / 金刚经卡副标 |
| `library_hub_in_depth` | `In-depth commentary` | `深度通释` | 精讲卡副标 |
| `library_hub_count_fmt` | `%d chapters` | `%d 章` | 卡下方的计数 |
| `chapter_fmt` | `Chapter %d` | `第 %d 章` | 精讲行章节号 |

`AppState.tr(_:)` 支持 variadic 格式化:`AppState.tr("library_hub_count_fmt", 81)` → "81 chapters" / "81 章"。

---

## 排序契约

`LibraryView.ttcEntries` / `diamondEntries` 都按 `display_order` 升序排:

```swift
private var ttcEntries: [LibraryEntry] {
    entries
        .filter { $0.source == "Tao Te Ching" }
        .sorted { $0.display_order < $1.display_order }
}
```

- **不要**用 `chapter` 字符串字典序排序(中文「第 1 章」「第 10 章」会错位)
- **不要**用 `verse_text` 长度或内容排序(后端可能改)
- 信任后端 `display_order` 字段;新增 source 时后端必须保证单调递增

---

## 启动契约

[TaoMindApp.swift#L19-L22](TaoMind-iOS/TaoMindApp.swift#L19-L22) 在 `init()` 同步预热 `JingjiangService`:

```swift
init() {
    SubscriptionManager.configure()
    Self.configureGoogleSignIn()
    // 修 build 48 Library hub 闪一下只显示 2 张卡的 bug
    JingjiangService.shared.load()
}
```

**不要**把 jingjiang load 推迟到 `LibraryView.task` —— 旧版就是这样,导致首次打开 Library 时 hub 闪一下只显 2 张卡。

---

## Build 49 后的合约差异

| Build | 行为 |
|---|---|
| 47 及之前 | LibraryView 194 章平铺(无 hub) |
| 48 | 3 入口卡 hub + sort by display_order;**首开 Library 闪一下只显 2 张卡** |
| 49(当前) | 同 build 48 + TaoMindApp 预热 jingjiang,首开直接 3 张卡 |
