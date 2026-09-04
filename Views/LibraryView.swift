import SwiftUI

// MARK: - Library (经藏) — 入口 Hub
//
// build 48 改造：原「194 章全展开列表」太重，改为 3 个入口卡：
//   1) 《道德经》原文  → LibrarySourceView（81 章，按 display_order 升序）
//   2) 《金刚经》原文  → LibrarySourceView（32 章，按 display_order 升序）
//   3) 《道德经》精讲  → LibraryJingjiangView（81 章，前 3 章免费）

struct LibraryView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var entries: [LibraryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var jingjiang = JingjiangService.shared

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let err = errorMessage {
                    errorState(err)
                } else {
                    hubList
                }
            }
            .navigationTitle(AppState.tr("Library"))
            .paperBackground()
            .task {
                jingjiang.load()
                await load()
            }
        }
    }

    // MARK: 3 个入口卡

    private var hubList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(hubItems) { item in
                    NavigationLink(value: item.destination) {
                        LibraryHubCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            countText: item.countText,
                            icon: item.icon,
                            showPro: !subscriptionManager.isPro && item.requiresPro
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // 修设计审计 2026-09-02 Blocker 2：ScrollView 底部加 100pt 透明 inset，
            // 让最后一张卡不被 iOS tab bar 切。
            .safeAreaPadding(.bottom, 100)
        }
        .navigationDestination(for: LibraryDestination.self) { dest in
            switch dest {
            case .taoTeChing:
                LibrarySourceView(
                    title: AppState.tr("library_tao_te_ching"),
                    source: "Tao Te Ching",
                    entries: ttcEntries
                )
            case .diamondSutra:
                LibrarySourceView(
                    title: AppState.tr("library_diamond_sutra"),
                    source: "Diamond Sutra",
                    entries: diamondEntries
                )
            case .jingjiang:
                LibraryJingjiangView()
            }
        }
    }

    private func errorState(_ err: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(err)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(AppState.tr("Retry")) {
                Task { await load() }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DS.ink)
            .foregroundColor(.white)
            .cornerRadius(DS.Radius.small)
        }
        .padding()
    }

    // MARK: 数据切片（原文部分按 display_order 升序）

    private var ttcEntries: [LibraryEntry] {
        entries
            .filter { $0.source == "Tao Te Ching" }
            .sorted { $0.display_order < $1.display_order }
    }

    private var diamondEntries: [LibraryEntry] {
        entries
            .filter { $0.source == "Diamond Sutra" }
            .sorted { $0.display_order < $1.display_order }
    }

    private var hubItems: [LibraryHubItem] {
        var items: [LibraryHubItem] = [
            LibraryHubItem(
                id: "ttc",
                title: AppState.tr("library_tao_te_ching"),
                subtitle: AppState.tr("library_hub_original"),
                countText: AppState.tr("library_hub_count_fmt", ttcEntries.count),
                icon: "book.closed.fill",
                requiresPro: false,
                destination: .taoTeChing
            ),
            LibraryHubItem(
                id: "diamond",
                title: AppState.tr("library_diamond_sutra"),
                subtitle: AppState.tr("library_hub_original"),
                countText: AppState.tr("library_hub_count_fmt", diamondEntries.count),
                icon: "diamond.fill",
                requiresPro: false,
                destination: .diamondSutra
            ),
        ]
        if !jingjiang.chapters.isEmpty {
            items.append(LibraryHubItem(
                id: "jingjiang",
                title: AppState.tr("library_jingjiang"),
                subtitle: AppState.tr("library_hub_in_depth"),
                countText: AppState.tr("library_hub_count_fmt", jingjiang.chapters.count),
                icon: "text.book.closed.fill",
                requiresPro: true,
                destination: .jingjiang
            ))
        }
        return items
    }

    // MARK: 网络加载

    private func load() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await api.fetchLibrary()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                entries = result.entries
                isLoading = false
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Hub 路由目标

private enum LibraryDestination: Hashable {
    case taoTeChing
    case diamondSutra
    case jingjiang
}

// MARK: - Hub Item 描述

private struct LibraryHubItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let countText: String
    let icon: String
    let requiresPro: Bool
    let destination: LibraryDestination
}

// MARK: - Hub Card 视图

private struct LibraryHubCard: View {
    let title: String
    let subtitle: String
    let countText: String
    let icon: String
    let showPro: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DS.bronze.opacity(0.10))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(DS.bronze)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.ink)
                    if showPro {
                        Text(AppState.tr("library_jingjiang_pro"))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.cinnabar.opacity(0.12))
                            .foregroundColor(DS.cinnabar)
                            .cornerRadius(3)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(DS.inkSoft)
                Text(countText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.paperHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.bronze.opacity(0.30), lineWidth: 1)
        )
    }
}
