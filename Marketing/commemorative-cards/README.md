# 珍藏纪念卡 · 营销用完整卡面

1-30 章（道德经前 30 章）竖排经文 + 楷体章号 + 英文题字 + ☯ TaoMind 落款。

**1440×2560 竖图**，适合公众号头图、小红书 / 知乎配图、Product Hunt gallery、X / Facebook 帖子。

## 文件清单

- `1_final.jpg` … `30_final.jpg` —— 每章一张
- 中文竖排经文 + 楷体章号（如"第一章"）
- 左上英文题字（Times Italic）
- 左下"☯ TaoMind 修行珍藏"落款
- 右下红色印章（已 v6 清理过水印）

## 来源

- 源图：`Card/N.jpg`（即梦 AI 生图，1440×2560）
- 处理：`demo/remove_wm_v6.py`（v3 外清 + v6 印章底缘水印 TELEA inpaint）
- 加字：`demo/add_card_text.py`（PIL 楷体 + Times Italic + ☯ 符号）

## 配套 App 素材

iOS 端用的是**无字版**（`Resources/Assets.xcassets/CardArt-N.imageset/CardArt-N.jpg`），
由 `demo/make_imagesets.py` 从 `Card/N_clean.jpg` 重新编码进 Xcode 资产（q85）。
final 营销版**不进 App**——App 内的分享卡由 `Views/ShareCardView.swift` 的
`ImageRenderer` 实时渲染，不依赖预生成图。
