# Resolution Center 回复（Guideline 2.1(b) — 1.3.1 重新提交时粘贴）

> 说明：本次回复配合 build 29 一起提交。build 29 的改动：
> 1) Lifetime 买断现在会出现在 paywall 上（之前它挂在独立的 RevenueCat offering 里，app 只读取 current offering，导致 Lifetime 选项不可见——这正是审核员找不到 IAP 的根因）；
> 2) offerings 加载失败时 paywall 会重试并显示重试按钮，不再出现无购买选项的空白页；
> 3) taomind_pro_lifetime 已随本版本一起提交审核。

---

**English (paste into Resolution Center):**

Thank you for your review, and apologies for the confusion.

We have updated the app (build 29) to make our In-App Purchases clearly accessible:

1. **Where to find the purchases**: Launch the app → on the "Seek Wisdom" tab, tap the locked style row (or any Pro-locked feature in Practice/Journal/Library) → the "Unlock TaoMind Premium" paywall appears, listing all plans: **TaoMind Pro Monthly, Quarterly, Yearly, and Lifetime (one-time purchase)**. The same paywall is reachable from Profile → Settings → "Upgrade to Pro".

2. **What we fixed in build 29**: The Lifetime option was previously served through a separate offering that the paywall did not display. Build 29 merges all plans onto the paywall, so every IAP submitted with this version ("TaoMind Pro Monthly/Quarterly/Yearly/Lifetime") is directly purchasable in the app. We have also attached the new "TaoMind Pro Lifetime" in-app purchase to this version submission.

3. If purchases fail to load due to connectivity, the paywall now retries automatically and shows a Retry button instead of an empty page.

We believe all in-app purchases can now be easily located and purchased. Please let us know if anything else is needed.

---

**中文对照（仅供自查，不粘贴）：**

感谢审核。我们已在 build 29 中更新：
1. **购买入口**：启动 app → "Seek Wisdom" 页点击锁定样式行（或 Practice/Journal/Library 中任意 Pro 锁定功能）→ 弹出 "Unlock TaoMind Premium" paywall，列出全部套餐：Monthly/Quarterly/Yearly/Lifetime（一次性买断）。Settings → "Upgrade to Pro" 也能到达同一 paywall。
2. **修复内容**：Lifetime 之前挂在 paywall 未读取的独立 offering 上（审核员看不到的根因）；build 29 已把全部套餐合并显示，且 taomind_pro_lifetime 已随本版本提交。
3. offerings 加载失败时自动重试并显示重试按钮，不再出现空白 paywall。
