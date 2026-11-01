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
            // 普通内容留白。原来这里写死 100pt 去「躲 tab bar」——那是重复补偿：
            // ScrollView 本来就在 tab bar 的安全区内。iPhone Duo 展开后 tab bar 移到
            // 右缘，这 100pt 会变成底部死白。（safeAreaPadding 是 iOS 17+，本工程部署 iOS 16）
            .padding(.bottom, 16)
            // 展开态限宽：7 张入口卡是「图标 + 标题 + 副标题 + 计数 + chevron」的横向行，
            // 铺满内屏宽后每张卡中间空出大片。限到 640 居中；窄屏可用宽本就不足 640，行为不变。
            // 加在 VStack 上而非 ScrollView 上：滚动区域保持全宽，只有内容列居中。
            .readableColumn(max: 640)
        }
        .navigationDestination(for: LibraryDestination.self) { dest in
            switch dest {
            case .taoTeChing:
                LibrarySourceView(
                    title: AppState.tr("library_tao_te_ching"),
                    source: "Tao Te Ching",
                    entries: ttcEntries
                )
            case .ganying:
                LibrarySourceView(
                    title: AppState.tr("library_ganying"),
                    source: "太上感应篇",
                    entries: ganyingEntries
                )
            case .qingjing:
                LibrarySourceView(
                    title: AppState.tr("library_qingjing"),
                    source: "清静经",
                    entries: qingjingEntries
                )
            case .liezi:
                LibrarySourceView(
                    title: AppState.tr("library_liezi"),
                    source: "列子",
                    entries: lieziEntries
                )
            case .zhuangzi:
                LibrarySourceView(
                    title: AppState.tr("library_zhuangzi"),
                    source: "庄子",
                    entries: zhuangziEntries
                )
            case .diamondSutra:
                LibrarySourceView(
                    title: AppState.tr("library_diamond_sutra"),
                    source: "Diamond Sutra",
                    entries: diamondEntries
                )
            case .jingjiang:
                LibraryJingjiangView()
            case .dasheng:
                LibrarySourceView(
                    title: AppState.tr("library_dasheng"),
                    source: "大乘佛法开示",
                    entries: dashengEntries
                )
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

    /// 太上感应篇（2026-09-11 新增）。source 是中文，与后端 seed 一致。
    private var ganyingEntries: [LibraryEntry] {
        entries
            .filter { $0.source == "太上感应篇" }
            .sorted { $0.display_order < $1.display_order }
    }

    /// 清静经 / 列子（2026-09-11 第二批）
    private var qingjingEntries: [LibraryEntry] {
        entries.filter { $0.source == "清静经" }.sorted { $0.display_order < $1.display_order }
    }
    private var lieziEntries: [LibraryEntry] {
        entries.filter { $0.source == "列子" }.sorted { $0.display_order < $1.display_order }
    }

    /// 庄子精选（2026-09-12）。source 是中文，与后端 seed 一致。
    private var zhuangziEntries: [LibraryEntry] {
        entries.filter { $0.source == "庄子" }.sorted { $0.display_order < $1.display_order }
    }

    /// 大乘佛法开示（2026-10-31）。source 是中文，与后端 seed 一致。
    private var dashengEntries: [LibraryEntry] {
        entries.filter { $0.source == "大乘佛法开示" }.sorted { $0.display_order < $1.display_order }
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
                id: "ganying",
                title: AppState.tr("library_ganying"),
                subtitle: AppState.tr("library_hub_treatise"),
                countText: AppState.tr("library_hub_count_fmt", ganyingEntries.count),
                icon: "scroll.fill",
                requiresPro: false,
                destination: .ganying
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
        if !qingjingEntries.isEmpty {
            items.append(LibraryHubItem(
                id: "qingjing",
                title: AppState.tr("library_qingjing"),
                subtitle: AppState.tr("library_hub_treatise"),
                countText: AppState.tr("library_hub_count_fmt", qingjingEntries.count),
                icon: "leaf.fill",
                requiresPro: false,
                destination: .qingjing
            ))
        }
        if !lieziEntries.isEmpty {
            items.append(LibraryHubItem(
                id: "liezi",
                title: AppState.tr("library_liezi"),
                subtitle: AppState.tr("library_hub_treatise"),
                countText: AppState.tr("library_hub_count_fmt", lieziEntries.count),
                icon: "book.pages.fill",
                requiresPro: false,
                destination: .liezi
            ))
        }
        if !zhuangziEntries.isEmpty {
            items.append(LibraryHubItem(
                id: "zhuangzi",
                title: AppState.tr("library_zhuangzi"),
                subtitle: AppState.tr("library_hub_original"),
                countText: AppState.tr("library_hub_count_fmt", zhuangziEntries.count),
                icon: "wind",
                requiresPro: false,
                destination: .zhuangzi
            ))
        }
        if !dashengEntries.isEmpty {
            items.append(LibraryHubItem(
                id: "dasheng",
                title: AppState.tr("library_dasheng"),
                subtitle: AppState.tr("library_hub_teachings"),
                countText: AppState.tr("library_hub_talks_fmt", dashengEntries.count),
                icon: "sparkles",
                requiresPro: false,
                destination: .dasheng
            ))
        }
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
    case ganying
    case qingjing
    case liezi
    case zhuangzi
    case diamondSutra
    case jingjiang
    case dasheng
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
