# Library Hub · How-To

3 个具体操作,每步都给代码位置 + 验证。

---

## How to 给 hub 加第 4 个源(例如《庄子》)

假设后端已经把庄子 33 篇加进 `/library` 响应,`source: "Zhuangzi"`。

### Step 1:加 i18n 字符串

`Resources/en.lproj/Localizable.strings` line 87 附近:

```text
"library_zhuangzi" = "Zhuangzi";
```

`Resources/zh-Hans.lproj/Localizable.strings` line 215 附近:

```text
"library_zhuangzi" = "《庄子》";
```

### Step 2:扩展 `LibraryDestination` enum

[TaoMind-iOS/Views/LibraryView.swift#L182-L186](TaoMind-iOS/Views/LibraryView.swift#L182-L186):

```swift
private enum LibraryDestination: Hashable {
    case taoTeChing
    case diamondSutra
    case zhuangzi           // 新增
    case jingjiang
}
```

### Step 3:加 `zhuangziEntries` 切片

[TaoMind-iOS/Views/LibraryView.swift#L109-L119](TaoMind-iOS/Views/LibraryView.swift#L109-L119) 旁边:

```swift
private var zhuangziEntries: [LibraryEntry] {
    entries
        .filter { $0.source == "Zhuangzi" }
        .sorted { $0.display_order < $1.display_order }
}
```

### Step 4:加 `LibraryHubItem`

[TaoMind-iOS/Views/LibraryView.swift#L121-L154](TaoMind-iOS/Views/LibraryView.swift#L121-L154) 的 `hubItems` 数组 `append`:

```swift
LibraryHubItem(
    id: "zhuangzi",
    title: AppState.tr("library_zhuangzi"),
    subtitle: AppState.tr("library_hub_original"),
    countText: AppState.tr("library_hub_count_fmt", zhuangziEntries.count),
    icon: "leaf.fill",
    requiresPro: false,
    destination: .zhuangzi
),
```

### Step 5:`navigationDestination` 加 case

[TaoMind-iOS/Views/LibraryView.swift#L64-L81](TaoMind-iOS/Views/LibraryView.swift#L64-L81):

```swift
case .zhuangzi:
    LibrarySourceView(
        title: AppState.tr("library_zhuangzi"),
        source: "Zhuangzi",
        entries: zhuangziEntries
    )
```

### 验证

```bash
cd C:\Users\Cyan\Desktop\TaoMind-iOS
xcodegen generate   # 不需要新建文件,不用跑
```

CI 编译通过 → 4 张卡出现 → 点庄子卡 → 33 篇按 `display_order` 升序排列 → 前 5 章可读,后续弹 paywall。

**注意**:en 跟 zh-Hans 字符串都要加,否则中英切换会显示 key 名。

---

## How to 改免费章节数(原文 / 精讲)

### 原文(LibrarySourceView)

文件:[TaoMind-iOS/Views/LibrarySourceView.swift#L17](TaoMind-iOS/Views/LibrarySourceView.swift#L17)

```swift
private let freeTasteCount = 5   // 改这里
```

注意:**客户端 freeTasteCount 决定 UI 是否弹 paywall**,但实际数据门控在 **服务端** `GET /library`(`APIClient.swift#L124` 注释:「服务端按 Pro 下发完整原文,免费用户仅前 5 章」)。如果只改客户端不改服务端,非 Pro 用户能看见但能点开前 5 章之后的内容(服务端会发,客户端不会锁)—— **必须前后端同时改**。

### 精讲(LibraryJingjiangService)

文件:[TaoMind-iOS/Services/JingjiangService.swift#L19-L22](TaoMind-iOS/Services/JingjiangService.swift#L19-L22)

```swift
static let freeChapterCount = 3   // 改这里
```

精讲是 bundle 数据,改这一处即生效(前后端都打客户端)。

### 验证

- 跑 `gh workflow run "Build TaoMind" -f create_ipa=true -f submit_review=false` 出新 build
- TestFlight 安装,非 Pro 账号:
  - 进道德经 → 第 6 章点开应弹 paywall
  - 进精讲 → 第 4 章点开应弹 paywall

---

## How to 给 hub 加新语言

项目目前只支持 `en` + `zh-Hans` 两种 locale(`TaoMindApp.swift:215` `Language.localeId`)。

### Step 1:加新 `Language` case

[TaoMind-iOS/TaoMindApp.swift#L200-L218](TaoMind-iOS/TaoMindApp.swift#L200-L218):

```swift
enum Language: String, CaseIterable {
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"      // 新增

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        }
    }

    var localeId: String {
        switch self {
        case .english: return "en"
        case .chinese: return "zh-Hans"
        case .japanese: return "ja"     // 对应 .lproj 目录名
        }
    }
}
```

### Step 2:加 `.lproj` 目录

在 `Resources/` 下建 `ja.lproj/Localizable.strings`,把所有 key 翻译成日文(包括 hub 用的 3 个新 key):

```text
"library_hub_original" = "原文";
"library_hub_in_depth" = "深掘り";
"library_hub_count_fmt" = "%d 章";
"library_tao_te_ching" = "道徳経";
...
```

### Step 3:加进 bundle

`project.yml` 检查 `Resources` 路径是否包含 `ja.lproj`(xcodegen 默认会扫到,但要确认):

```yaml
info:
  path: Resources
```

### Step 4:设置页加切换入口

`Views/SettingsView.swift` 的语言选择段加一行日文,绑定到 `appState.language = .japanese`。

### 验证

- 切到日文 → 重启 app(或者 .onChange 触发 refresh)
- Library tab 全部 key 显示日文,包括 "原文" / "深掘り" / "81 章"
- `AppState.tr("library_hub_count_fmt", 81)` → "81 章"(不是 "81 chapters" 也不是 key 名)

---

## How to 调试 jingjiang 没显示

症状:Library tab 只看到 2 张卡(道德经 + 金刚经),没有精讲卡。

### 排查路径

1. **看 log**:
   - 启动时打 `[Jingjiang] ✅ loaded 81 chapters` → 正常
   - 启动时打 `[Jingjiang] ❌ jingjiang.json not found in bundle` → bundle 没打包,看 `project.yml` 资源路径
   - 启动时打 `[Jingjiang] ❌ JSON decode failed: ...` → JSON 文件格式错,跑 `python -m json.tool Resources/jingjiang.json | head`

2. **确认 `TaoMindApp.init()` 调了 `JingjiangService.shared.load()`**:
   - [TaoMind-iOS/TaoMindApp.swift#L22](TaoMind-iOS/TaoMindApp.swift#L22) 必须有
   - 如果没有,build 48 行为:首次打开 Library → 2 张卡,延迟 1 帧后 3 张卡

3. **确认 `jingjiang.chapters` 真的非空**:
   ```swift
   // 在 LibraryView body 顶端加临时 log
   .onAppear { print("[Library] jingjiang chapters: \(jingjiang.chapters.count)") }
   ```

4. **iOS 16 设备上 hub 卡数对**:3 张全显 → ✓

### 修复示例

如果 `jingjiang.json` 漏打包,修 `project.yml`:

```yaml
targets:
  TaoMind:
    sources:
      - path: Resources
```

xcodegen 默认会扫整个目录,确认 `Resources/jingjiang.json` 存在。

---

## 常见错误

### 编译报 "Main actor-isolated static property 'currentLocaleId'"

`JingjiangChapter.localized*` 访问器是 `@MainActor`(因为 `AppState.currentLocaleId` 是)。在 `LibraryJingjiangView` body 里读 `chapter.localizedTongshi` 是安全的(整个 SwiftUI body 在 main actor)。**不要**把这些 `@MainActor` 标去掉 —— 修法是在不 main-actor 的地方用 `await MainActor.run { ... }`。

### 编译报 "safeAreaPadding is only available in iOS 17.0 or newer"

[LibraryView.swift#L60-L62](TaoMind-iOS/Views/LibraryView.swift#L60-L62) 用的是 `.padding(.bottom, 100)`(非 `safeAreaPadding`)。后者是 iOS 17+,工程部署 iOS 16,会编译失败。

### 编译报 "'tertiary' cannot be used on type 'Color?'"

[LibrarySourceView.swift#L70](TaoMind-iOS/Views/LibrarySourceView.swift#L70) 跟 [LibraryJingjiangView.swift#L77](TaoMind-iOS/Views/LibraryJingjiangView.swift#L77) 用的是 `.foregroundStyle(.tertiary)`(不是 `.foregroundColor(.tertiary)`)。前者接受 `ShapeStyle`,后者只接受 `Color`,而 `.tertiary` 是 `HierarchicalShapeStyle`。

### 点 hub 卡不跳转

检查 `LibraryDestination` 的 case 都加进 `navigationDestination` 的 switch 了。漏 case → SwiftUI 会 warning 但不 crash,表现就是点卡无反应。
