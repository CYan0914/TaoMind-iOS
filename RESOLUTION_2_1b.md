# 2.1(b) 被拒 — 你回来后只需做这一件事（约 5 分钟）

> 已自动完成：build 29 上传 TestFlight ✓ / paywall 显示 Lifetime ✓ / offerings 重试+兜底 ✓ /
> What's New 已填 ✓ / build 已关联版本 ✓ / release.yml 已修复并推送 ✓
>
> **唯一剩的**：Resolution Center 的拒绝信必须由账号持有人在网页上回复（Apple 无开放此 API，
> 我试了 reviewSubmissions API 全部路径，UNRESOLVED_ISSUES 状态下 submitted=true 一律 409）。

## 浏览器操作步骤

1. 打开 https://appstoreconnect.apple.com → 我的 App → **TaoMind**
2. 左侧 **1.3.1** 版本 → 找到被拒提示（未解决的问题）点进去，或左侧「App 审核」区
3. 进入 **Resolution Center**（解决问题）→ 点开审核员的拒绝消息 → **回复**
4. 把下面英文整段粘进去，发送
5. 回到 1.3.1 版本页 → 右上角「**添加以进行审核**」/「重新提交至 App 审核」按钮应该已亮起
6. 提交页里确认包含：**1.3.1 (build 29)** + IAP **taomind_pro_lifetime**（如果列表里没有 lifetime，
   在「App 内购买项目」区勾选它一起提交；订阅三个已过审不用管）
7. 点提交。搞定。

---

## 英文回复（直接粘贴）

Thank you for your review, and apologies for the confusion.

We have updated the app (build 29) to make our In-App Purchases clearly accessible:

1. **Where to find the purchases**: Launch the app → on the "Seek Wisdom" tab, tap the locked style row (or any Pro-locked feature in Practice/Journal/Library) → the "Unlock TaoMind Premium" paywall appears, listing all plans: **Monthly, Quarterly, Yearly, and Lifetime (one-time purchase)**. The same paywall is reachable from Profile → Settings → "Upgrade to Pro".

2. **What we fixed in build 29**: The Lifetime option was previously served through a separate offering that the paywall did not display. Build 29 merges all plans onto the paywall, so every IAP is directly purchasable in the app. We have also attached the new "TaoMind Pro Lifetime" in-app purchase to this version submission.

3. If purchases fail to load due to connectivity, the paywall now retries automatically and shows a Retry button instead of an empty page.

We believe all in-app purchases can now be easily located and purchased. Please let us know if anything else is needed.

---

## 技术备注（为什么被拒 + 改了什么）

- 根因①：lifetime 挂在 RevenueCat 独立 offering（identifier="lifetime"），app 只读 current offering
  → 审核员在 paywall 上根本看不到买断选项。
  修复：PaywallView.mergedPackages 合并两个 offering；PlanCard 对 .lifetime 显示 "One-time purchase"。
- 根因②：taomind_pro_lifetime 在 ASC 是 Ready to Submit，从未随版本提交 → 审核员看不到这个新 IAP。
  修复：挂到 version 随本次提交（脚本自动做了；若提交页没看到就手动勾选）。
- 根因③：offerings 加载失败时 paywall 空白无购买选项。
  修复：SubscriptionManager.fetchOfferings 重试 3 次；失败时显示错误文案 + Retry 按钮。
