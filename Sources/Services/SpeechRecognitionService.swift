import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Non-isolated Speech Recognition Worker (Thread-safe)
private final class AudioSpeechEngineWorker: @unchecked Sendable {
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentSessionId: UUID = UUID()
    private let lock = NSLock()

    var isRunning: Bool {
        audioEngine.isRunning
    }

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }

    func requestAuth() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized {
            return true
        }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startNewSession(
        sessionId: UUID,
        onText: @escaping @Sendable (String, UUID) -> Void,
        onError: @escaping @Sendable (Error?, UUID) -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        self.currentSessionId = sessionId

        // 既存タスクを安全にキャンセル
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognition", code: 2, userInfo: [NSLocalizedDescriptionKey: "日本語の音声認識エンジンが現在利用できません。"])
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            self.lock.lock()
            let activeId = self.currentSessionId
            self.lock.unlock()

            // 過去セッションの遅延コールバックは完全に無視
            guard activeId == sessionId else { return }

            if let result = result {
                onText(result.bestTranscription.formattedString, sessionId)
            }
            if error != nil || (result?.isFinal ?? false) {
                onError(error, sessionId)
            }
        }

        if !audioEngine.isRunning {
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.lock.lock()
                let req = self.recognitionRequest
                self.lock.unlock()
                req?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        currentSessionId = UUID() // セッション無効化

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - MainActor ViewModel Service
@MainActor
public final class SpeechRecognitionService: ObservableObject {
    public static let shared = SpeechRecognitionService()

    @Published public var isRecording: Bool = false
    @Published public var isAlwaysListening: Bool = false
    @Published public var recognizedText: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var isAuthorized: Bool = false

    private let worker = AudioSpeechEngineWorker()
    private var currentSessionId: UUID = UUID()
    private var onUpdateHandler: (@Sendable (String) -> Void)?
    private var onAutoSendHandler: (@Sendable () -> Void)?
    private var autoSendTimer: Task<Void, Never>? = nil
    private var backgroundActivity: NSObjectProtocol? = nil

    private init() {
        self.isAuthorized = (SFSpeechRecognizer.authorizationStatus() == .authorized)
    }

    /// 音声認識の権限を要求
    public func requestAuthorizationIfNeeded() async -> Bool {
        let granted = await worker.requestAuth()
        self.isAuthorized = granted
        return granted
    }

    /// 音声認識の開始
    public func startRecording(
        onUpdate: @escaping @Sendable (String) -> Void,
        onAutoSendTrigger: (@Sendable () -> Void)? = nil
    ) async throws {
        let hasPermission = await requestAuthorizationIfNeeded()
        guard hasPermission else {
            throw NSError(domain: "SpeechRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "マイクまたは音声認識の権限が許可されていません。「システム設定 > プライバシーとセキュリティ」で許可してください。"])
        }

        // バックグラウンドでも省電力で止められないようにアクティビティを開始
        if backgroundActivity == nil {
            backgroundActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled, .latencyCritical],
                reason: "MyOllama Background Continuous Speech Assistant"
            )
        }

        errorMessage = nil
        recognizedText = ""
        self.onUpdateHandler = onUpdate
        self.onAutoSendHandler = onAutoSendTrigger

        try startNewRecognitionSession()
        self.isRecording = true
    }

    private func startNewRecognitionSession() throws {
        let newSessionId = UUID()
        self.currentSessionId = newSessionId
        self.recognizedText = ""

        try worker.startNewSession(
            sessionId: newSessionId,
            onText: { [weak self] text, sessId in
                Task { @MainActor in
                    guard let self = self, self.currentSessionId == sessId else { return }
                    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }

                    // ユーザーが喋り始めたら、AIの発話を即座に中断（バージイン）
                    if VoicevoxService.shared.isSpeaking {
                        VoicevoxService.shared.stop()
                    }

                    self.recognizedText = text
                    self.onUpdateHandler?(text)

                    // スマート自動送信タイマー
                    if let onAutoSend = self.onAutoSendHandler {
                        self.resetAutoSendTimer(currentText: text, trigger: onAutoSend)
                    }
                }
            },
            onError: { [weak self] _, sessId in
                Task { @MainActor in
                    guard let self = self, self.currentSessionId == sessId else { return }
                    if self.isAlwaysListening {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if self.isAlwaysListening && self.currentSessionId == sessId {
                            try? self.startNewRecognitionSession()
                        }
                    } else {
                        self.stopRecording()
                    }
                }
            }
        )
    }

    /// 送信完了時に音声認識バッファとセッションIDを完全にリフレッシュ
    public func resetRecognitionSession() {
        cancelAutoSendTimer()
        recognizedText = ""
        // 新しいセッションIDを発行して古いコールバックを完全遮断
        currentSessionId = UUID()

        if isAlwaysListening {
            // 0.05秒後に新しいクリーンな認識セッションを開始
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard self.isAlwaysListening else { return }
                try? self.startNewRecognitionSession()
            }
        } else if isRecording {
            stopRecording()
        }
    }

    /// 無音・文末検出による自動送信タイマー
    private func resetAutoSendTimer(currentText: String, trigger: @escaping @Sendable () -> Void) {
        autoSendTimer?.cancel()
        let delay = SmartVoiceTrigger.requiredSilenceDuration(for: currentText)

        autoSendTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                trigger()
            }
        }
    }

    public func cancelAutoSendTimer() {
        autoSendTimer?.cancel()
        autoSendTimer = nil
    }

    /// 音声認識の停止
    public func stopRecording() {
        cancelAutoSendTimer()
        currentSessionId = UUID()
        worker.stop()
        self.isRecording = false
        self.isAlwaysListening = false
        self.recognizedText = ""

        if let activity = backgroundActivity {
            ProcessInfo.processInfo.endActivity(activity)
            backgroundActivity = nil
        }
    }

    /// 単発録音のトグル
    public func toggleRecording(
        onUpdate: @escaping @Sendable (String) -> Void,
        onAutoSendTrigger: (@Sendable () -> Void)? = nil
    ) {
        if isRecording {
            stopRecording()
        } else {
            Task {
                do {
                    try await startRecording(onUpdate: onUpdate, onAutoSendTrigger: onAutoSendTrigger)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isRecording = false
                }
            }
        }
    }

    /// 常時リスニング（ハンズフリー）モードのトグル
    public func toggleAlwaysListening(
        onUpdate: @escaping @Sendable (String) -> Void,
        onAutoSendTrigger: (@Sendable () -> Void)? = nil
    ) {
        if isAlwaysListening {
            stopRecording()
        } else {
            self.isAlwaysListening = true
            Task {
                do {
                    try await startRecording(onUpdate: onUpdate, onAutoSendTrigger: onAutoSendTrigger)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isAlwaysListening = false
                    self.isRecording = false
                }
            }
        }
    }
}
