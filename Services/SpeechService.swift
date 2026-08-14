import SwiftUI
import Speech
import AVFoundation

// MARK: - Speech Service

/// 语音输入：用 Apple Speech 框架把口语问题转成文字（跟随 App 语言选择 zh-CN / en-US）。
@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published var isRecording = false
    /// 当前语言/设备是否支持语音识别（不可用时按钮置灰）
    @Published var isAvailable = true

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var currentTranscript = ""

    // MARK: - Authorization

    /// 请求语音识别权限；已授权直接返回 true。
    static func requestPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }

    // MARK: - Recording

    /// 开始录音识别。返回 false 表示设备/语言不支持或启动失败。
    func startRecording(localeId: String) -> Bool {
        // 上一轮还在录 → 先清理（避免重复 installTap 崩溃）
        if tapInstalled || audioEngine.isRunning {
            teardownRecording()
        }
        currentTranscript = ""

        // 语言跟随 App 设置：zh-Hans → zh-CN，其余 → en-US
        let speechLocale = Locale(identifier: localeId == "zh-Hans" ? "zh-CN" : "en-US")
        recognizer = SFSpeechRecognizer(locale: speechLocale)
        guard let recognizer = recognizer, recognizer.isAvailable else {
            isAvailable = false
            return false
        }
        isAvailable = true

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // 无输入设备（如模拟器）时采样率为 0，installTap 会崩溃 → 提前拦截
        guard recordingFormat.sampleRate > 0 else { return false }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            teardownRecording()
            return false
        }

        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // 回调在后台队列 → 跳到主线程再碰 @MainActor 状态
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.currentTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.teardownRecording()
                }
            }
        }

        return true
    }

    /// 停止录音并返回当前识别出的文字。
    func stopRecording() -> String {
        recognitionRequest?.endAudio()
        let transcript = currentTranscript
        currentTranscript = ""
        teardownRecording()
        return transcript
    }

    /// 停止引擎、移除 tap、释放请求/任务。幂等，可安全重复调用。
    private func teardownRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
