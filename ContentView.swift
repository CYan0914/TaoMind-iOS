import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var dailyVerse: DailyVerse?
    @State private var selectedTab = 0
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SeekWisdomView()
            }
            .tabItem {
                Label("Wisdom", systemImage: "sparkles")
            }
            .tag(0)

            NavigationStack {
                JournalView()
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }
            .tag(1)

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "flame")
            }
            .tag(2)

            // 修设计审计 2026-09-02 QW2：5 tab → 4 tab。
            // Library（经藏 / 《道德经》《金刚经》）从底 tab 移走，
            // 在 Practice 主屏里加一个 libraryEntry 入口（同 Commemorative Cards 入口模式）。
            // 原因：5 tab 拥挤 + iOS 默认纯黑 tab bar 拉低「高级感」。
            // Settings 保留在底 tab（不可替代的强入口）。

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
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
    }
}
