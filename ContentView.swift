import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var dailyVerse: DailyVerse?
    @State private var showOnboarding = false

    var body: some View {
        // selectedTab 住在 AppState 里而不是 @State —— SeekWisdomView 保存日志后
        // 要能直接跳到经藏 tab，@State 在 ContentView 内部无法被别的视图驱动。
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                SeekWisdomView()
            }
            .tabItem {
                Label("Wisdom", systemImage: "sparkles")
            }
            .tag(0)

            // 2026-09-10 恢复为独立 tab（用户决定，部分回退 2026-09-02 QW2）：
            // QW2 当时把 Library 从底 tab 移到 Practice 的 libraryEntry，理由是
            // 「5 tab 拥挤 + iOS 默认纯黑 tab bar 拉低高级感」。
            // 但实测下来：Library 是 Pro 转化的核心资产（81 章精讲 + 原文书库），
            // 藏在 Practice 二级入口 → 用户不进 Practice 就完全不知道这块的价值。
            // 取舍反转：tab bar 用 .warmTabBar() 已解决「纯黑」问题；多一个 tab
            // 换来核心资产常驻可见，值得。
            // ⚠️ Practice 里的 libraryEntry **保留**（双入口），不删。
            // LibraryView 自带 NavigationStack，这里不要再包一层。
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(1)

            NavigationStack {
                JournalView()
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }
            .tag(2)

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "flame")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        .tint(DS.bronze)
        // 修设计审计 2026-09-02 QW2：iOS 默认纯黑 tab bar → 暖宣纸 92% 透明。
        // 详见 DesignSystem.swift `extension View { func warmTabBar() }`。
        .warmTabBar()
        .onAppear {
            // 首启 onboarding（3 屏，仅一次）
            if !appState.hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        // 修付费墙 100% 自动退出 bug：原本 SeekWisdomView + SettingsView 各 attach 了一个
        // .sheet(isPresented: $subscriptionManager.showingPaywall)，两个 binding 同时驱动
        // 同一个 @Published 时 SwiftUI 内部状态冲突，sheet 第一次 present 瞬间被关掉。
        // 统一提到 ContentView 顶层（一个 binding 驱动一个 sheet），行为可预期。
        .sheet(isPresented: $subscriptionManager.showingPaywall) {
            PaywallView(context: subscriptionManager.paywallContext)
        }
        // 增值型邀请（区别于上面的惩罚型付费墙）：seek 保存到日志后引导进经藏。
        // 与付费墙是两个独立 binding，不会重演「同一 @Published 驱动两个 sheet」的冲突。
        .sheet(isPresented: $appState.showingLibraryInvite) {
            LibraryInviteView()
        }
    }
}
