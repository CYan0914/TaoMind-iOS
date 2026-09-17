import SwiftUI

// MARK: - 道德经·精讲 详情页
//
// 5 个 section: 原文 → 通释 → 反常识点 → 30yr PM scene → 张力 → 一句行动
// 2026-09-17：音频已下架（IPA 541MB → <80MB），本页只留文字。

struct JingjiangDetailView: View {
    let chapter: JingjiangChapter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                attribution
                originalVerse
                tongshiBlock
                counterBlock
                sceneBlock
                tensionBlock
                actionBlock
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .paperBackground()
        .navigationTitle(AppState.tr("library_jingjiang"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头标

    private var attribution: some View {
        Text("\(AppState.tr("library_jingjiang")) · \(AppState.tr("chapter_fmt", chapter.num))")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // MARK: - 原文

    private var originalVerse: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chapter.localizedOriginal)
                .font(.custom("Georgia", size: 19, relativeTo: .body))
                .foregroundColor(DS.ink)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 通释 (主文)

    private var tongshiBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Commentary", systemImage: "text.book.closed")
            Text(chapter.localizedTongshi)
                .font(.body)
                .foregroundColor(DS.inkSoft)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 反常识点 (callout)

    private var counterBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(AppState.tr("jingjiang_counter_title"), systemImage: "lightbulb")
            Text(chapter.localizedCounter)
                .font(.body)
                .foregroundColor(DS.ink)
                .lineSpacing(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.bronze.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.bronze.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - 30yr PM 场景

    private var sceneBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(AppState.tr("jingjiang_scene_title"), systemImage: "person.crop.rectangle")
            Text(chapter.localizedScene)
                .font(.body)
                .foregroundColor(DS.inkSoft)
                .lineSpacing(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.ink.opacity(0.04))
        )
    }

    // MARK: - 张力 (跟上一章)

    private var tensionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(AppState.tr("jingjiang_tension_title"), systemImage: "arrow.triangle.branch")
            Text(chapter.localizedTension)
                .font(.callout)
                .foregroundColor(DS.inkSoft)
                .lineSpacing(5)
        }
    }

    // MARK: - 一句行动 (action item, haptic on tap)

    private var actionBlock: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(DS.cinnabar)
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppState.tr("jingjiang_action_title"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(chapter.localizedAction)
                        .font(.body)
                        .foregroundColor(DS.ink)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.cinnabar.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(DS.cinnabar.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(DS.bronze)
            Text(title)
                .font(.headline)
                .foregroundColor(DS.ink)
        }
    }
}

// MARK: - 音频播放器已于 2026-09-17 移除
//
// 原来这里有个 `JingjiangAudioPlayer`（AVAudioPlayer 从 bundle 读 {slug}_{lang}.mp3）。
// 音频（81 × ~5.7MB ≈ 462MB）是 IPA 体积的 85%，且 81 个文件全是 `_en.mp3` ——
// 中文界面取 `chXX_cn.mp3` 永远 404，中文用户从来没听到过声音。
// 现已整块下架，App 只保留文字精讲。若要恢复，见 git 历史 96ce123。
