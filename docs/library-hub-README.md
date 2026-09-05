# Library Hub 文档索引

build 48 改造后的「经藏」入口模块,文档按 Diataxis 四象限拆分。

## 入口

[LibraryView](TaoMind-iOS/Views/LibraryView.swift#L10-L178) 是 Library tab 的根视图,展示 3 张入口卡。

## 文档

| 文件 | 象限 | 给谁看 | 内容 |
|---|---|---|---|
| [reference.md](reference.md) | Reference | 写新代码 / 找 API 签名 | 公共 surface 完整清单:视图、模型、字符串、PaywallContext |
| [howto.md](howto.md) | How-to | 要加新源 / 改 free tier / 加新语言 | 3 个具体操作步骤 + 验证 + 故障排查 |
| [explanation.md](explanation.md) | Explanation | 想理解"为什么这样设计" | hub vs 平铺、display_order 排序、jingjiang eager-load 三个设计决策 |

## 一页速览

- **3 张入口卡**:《道德经》原文、《金刚经》原文、《道德经》精讲
- **原文按 display_order 升序排序**(修 build 48 金刚经 1,4,7 章乱序 bug)
- **Pro 门控**:原文前 5 章免费,精讲前 3 章免费,其余走 paywall(`.libraryLocked` / `.jingjiangLocked`)
- **精讲数据从 bundle 读**(jingjiang.json ≈ 1.5MB,app 启动时预热,避免首开 Library 只显 2 张卡的闪烁)

## 关键文件

- `TaoMind-iOS/Views/LibraryView.swift` — 入口 hub
- `TaoMind-iOS/Views/LibrarySourceView.swift` — 原文列表(道德经/金刚经)
- `TaoMind-iOS/Views/LibraryJingjiangView.swift` — 精讲列表
- `TaoMind-iOS/Models/Checkin.swift#L103-L117` — `LibraryEntry` / `LibraryResponse` 模型
- `TaoMind-iOS/Services/JingjiangService.swift` — 精讲 bundle 加载
- `TaoMind-iOS/Services/SubscriptionManager.swift#L8-L13` — `PaywallContext` 枚举
- `TaoMind-iOS/TaoMindApp.swift#L19-L22` — 启动时预热 `JingjiangService`
- `TaoMind-iOS/Resources/{en,zh-Hans}.lproj/Localizable.strings` — i18n

## 历史

- build 46:新增「道德经·精讲」section(平铺)
- build 47:精讲扩到 81 章,前 3 章免费
- **build 48**:**改造为 3 入口卡 hub** + 修金刚经/道德经排序
- build 49:启动时 eager-load jingjiang(修 build 48 引入的 2 张卡闪烁)
