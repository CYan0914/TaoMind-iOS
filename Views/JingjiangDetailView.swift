import SwiftUI
import AVFoundation

// MARK: - 道德经·精讲 详情页
//
// 6 个 section: 原文 (含 audio player) → 通释 → 反常识点 → 30yr PM scene → 张力 → 一句行动
// Audio 用 AVFoundation 的 AVAudioPlayer, 文件从 bundle 读 jingjiang_audio/{slug}_{lang}.mp3

struct JingjiangDetailView: View {
    let chapter: JingjiangChapter
    @Environment(\.dismiss) private var dismiss

    @StateObject private var audio = JingjiangAudioPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                attribution
                originalVerse
                audioCard
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
        .onAppear {
            audio.loadIfNeeded(fileName: chapter.audioFileName)
        }
        .onDisappear {
            audio.stop()
        }
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

    // MARK: - 音频卡 (AVAudioPlayer)

    private var audioCard: some View {
        HStack(spacing: 14) {
            Button {
                audio.toggle()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(DS.cinnabar)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(AppState.tr(audio.isPlaying ? "jingjiang_pause_audio" : "jingjiang_play_audio"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DS.ink)
                Text(audio.statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if audio.isReady {
                Text(timeString(audio.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.paperHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.ink.opacity(0.08), lineWidth: 1)
        )
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

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Audio Player (per-instance, holds AVAudioPlayer)

@MainActor
final class JingjiangAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isReady = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var statusLine: String = ""

    private var player: AVAudioPlayer?
    private var loadedFileName: String?

    func loadIfNeeded(fileName: String?) {
        guard let fileName else {
            statusLine = AppState.tr("jingjiang_no_audio")
            return
        }
        if loadedFileName == fileName { return }
        loadedFileName = fileName

        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            statusLine = AppState.tr("jingjiang_no_audio")
            isReady = false
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            self.player = p
            self.duration = p.duration
            self.isReady = p.duration > 0
            self.statusLine = isReady ? "\(AppState.tr("jingjiang_play_audio")) · \(timeString(p.duration))" : AppState.tr("jingjiang_no_audio")
        } catch {
            statusLine = AppState.tr("jingjiang_no_audio")
            isReady = false
        }
    }

    func toggle() {
        guard let p = player, p.duration > 0 else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            statusLine = AppState.tr("jingjiang_play_audio")
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            p.play()
            isPlaying = true
            statusLine = AppState.tr("jingjiang_pause_audio")
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.statusLine = AppState.tr("jingjiang_play_audio")
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
