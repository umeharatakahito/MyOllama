import Foundation
import AVFoundation

public struct ZundamonStyle: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String

    public static let allStyles: [ZundamonStyle] = [
        ZundamonStyle(id: 3, name: "ノーマル"),
        ZundamonStyle(id: 1, name: "あまあま"),
        ZundamonStyle(id: 7, name: "ツンツン"),
        ZundamonStyle(id: 5, name: "セクシー"),
        ZundamonStyle(id: 22, name: "ささやき"),
        ZundamonStyle(id: 38, name: "ヒソヒソ"),
        ZundamonStyle(id: 75, name: "ヘロヘロ"),
        ZundamonStyle(id: 76, name: "なみだめ")
    ]
}

private final class AudioPlayerDelegateHandler: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable () -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }

    func audioPlayerDecodeErrorDidFinishPlaying(_ player: AVAudioPlayer, error: (any Error)?) {
        onFinish?()
    }
}

@MainActor
public final class VoicevoxService: ObservableObject {
    public static let shared = VoicevoxService()

    @Published public var isSpeaking: Bool = false
    @Published public var isAvailable: Bool = false

    private var audioPlayer: AVAudioPlayer?
    private let delegateHandler = AudioPlayerDelegateHandler()
    private let baseURL = URL(string: "http://127.0.0.1:50021")!

    // 逐次ストリーミングキュー用
    private var audioQueue: [Data] = []
    private var activeSynthesisCount: Int = 0
    private var isCancelled: Bool = false
    private var watchdogTask: Task<Void, Never>?

    public var isActuallyPlaying: Bool {
        return (audioPlayer?.isPlaying ?? false) || !audioQueue.isEmpty || activeSynthesisCount > 0
    }

    private init() {
        delegateHandler.onFinish = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.audioPlayer = nil
                self.processNextInQueue()
            }
        }
        Task {
            await checkAvailability()
        }
        startBackgroundWatchdog()
    }

    /// App Nap（バックグラウンド省電力）の影響を受けない高精度非同期監視ループ
    private func startBackgroundWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    if self.isSpeaking {
                        if let player = self.audioPlayer {
                            if !player.isPlaying {
                                self.audioPlayer = nil
                                self.processNextInQueue()
                            }
                        } else if self.audioQueue.isEmpty && self.activeSynthesisCount == 0 {
                            self.isSpeaking = false
                        }
                    }
                }
            }
        }
    }

    /// VOICEVOXサーバーの接続確認
    public func checkAvailability() async {
        let endpoint = baseURL.appendingPathComponent("version")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 3
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty {
                self.isAvailable = true
            } else {
                self.isAvailable = false
            }
        } catch {
            self.isAvailable = false
        }
    }

    /// 単発の文章を即座に読み上げる（キューをリセットして再生）
    public func speak(text: String, speakerId: Int = 3, speedScale: Double = 1.0) {
        stop()

        let cleanText = preprocessTextForSpeech(text)
        guard !cleanText.isEmpty else { return }

        isCancelled = false
        isSpeaking = true
        activeSynthesisCount += 1

        Task {
            defer {
                Task { @MainActor in
                    self.activeSynthesisCount = max(0, self.activeSynthesisCount - 1)
                    self.checkIfFinished()
                }
            }

            do {
                let wavData = try await generateSpeechData(text: cleanText, speakerId: speakerId, speedScale: speedScale)
                guard !self.isCancelled else { return }

                await MainActor.run {
                    guard !self.isCancelled else { return }
                    self.playWavDirect(wavData)
                }
            } catch {
                // 合成エラー
            }
        }
    }

    /// ストリーミング逐次生成用：1文または1行のチャンクをキューに追加して順次再生
    public func enqueueChunk(text: String, speakerId: Int = 3, speedScale: Double = 1.0) {
        let clean = preprocessTextForSpeech(text)
        guard !clean.isEmpty else { return }

        isCancelled = false
        isSpeaking = true
        activeSynthesisCount += 1

        Task {
            defer {
                Task { @MainActor in
                    self.activeSynthesisCount = max(0, self.activeSynthesisCount - 1)
                    self.checkIfFinished()
                }
            }

            do {
                let wavData = try await generateSpeechData(text: clean, speakerId: speakerId, speedScale: speedScale)
                guard !self.isCancelled else { return }

                await MainActor.run {
                    guard !self.isCancelled else { return }
                    self.audioQueue.append(wavData)
                    if self.audioPlayer == nil {
                        self.processNextInQueue()
                    }
                }
            } catch {
                // 合成エラー時はスキップ
            }
        }
    }

    /// キューの先頭を再生
    private func processNextInQueue() {
        guard !isCancelled else {
            stop()
            return
        }

        if !audioQueue.isEmpty {
            let nextData = audioQueue.removeFirst()
            playWavDirect(nextData)
        } else {
            checkIfFinished()
        }
    }

    private func playWavDirect(_ data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self.delegateHandler
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
            self.isSpeaking = true
        } catch {
            self.audioPlayer = nil
            self.processNextInQueue()
        }
    }

    /// 発話がすべて終了したかを判定
    public func checkIfFinished() {
        let isPlayerPlaying = audioPlayer?.isPlaying ?? false
        if audioQueue.isEmpty && activeSynthesisCount == 0 && !isPlayerPlaying {
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }

    /// 音声停止（再生＆キュー＆保留タスクの全破棄・即時聴くモード移行可能）
    public func stop() {
        isCancelled = true
        activeSynthesisCount = 0
        audioQueue.removeAll()

        if let player = audioPlayer {
            player.stop()
        }
        audioPlayer = nil
        isSpeaking = false
    }

    // MARK: - Internal API calls
    private func generateSpeechData(text: String, speakerId: Int, speedScale: Double) async throws -> Data {
        guard var queryComponents = URLComponents(url: baseURL.appendingPathComponent("audio_query"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        queryComponents.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "speaker", value: String(speakerId))
        ]

        guard let queryURL = queryComponents.url else {
            throw URLError(.badURL)
        }

        var queryRequest = URLRequest(url: queryURL)
        queryRequest.httpMethod = "POST"
        queryRequest.timeoutInterval = 15

        let (queryData, queryResp) = try await URLSession.shared.data(for: queryRequest)
        guard let httpQuery = queryResp as? HTTPURLResponse, (200...299).contains(httpQuery.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 速度調整の反映
        var modifiedQueryData = queryData
        if speedScale != 1.0 {
            if var json = try? JSONSerialization.jsonObject(with: queryData) as? [String: Any] {
                json["speedScale"] = speedScale
                if let updated = try? JSONSerialization.data(withJSONObject: json) {
                    modifiedQueryData = updated
                }
            }
        }

        // Synthesis
        guard var synthComponents = URLComponents(url: baseURL.appendingPathComponent("synthesis"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        synthComponents.queryItems = [
            URLQueryItem(name: "speaker", value: String(speakerId))
        ]

        guard let synthURL = synthComponents.url else {
            throw URLError(.badURL)
        }

        var synthRequest = URLRequest(url: synthURL)
        synthRequest.httpMethod = "POST"
        synthRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        synthRequest.httpBody = modifiedQueryData
        synthRequest.timeoutInterval = 30

        let (wavData, synthResp) = try await URLSession.shared.data(for: synthRequest)
        guard let httpSynth = synthResp as? HTTPURLResponse, (200...299).contains(httpSynth.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return wavData
    }

    /// 発話用にテキストを整形（思考タグ、コードブロック、記号などの除去）
    public func preprocessTextForSpeech(_ raw: String) -> String {
        var text = raw

        // 思考タグ <think>...</think> の除去
        if let start = text.range(of: "<think>") {
            if let end = text.range(of: "</think>") {
                text.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                return ""
            }
        }

        // コードブロック ```...``` の除去または簡略化
        text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: "（コード省略）", options: .regularExpression)
        // インラインコード `...` の記号除去
        text = text.replacingOccurrences(of: "`", with: "")

        // Markdownリンク [title](url) -> title
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)

        // 見出し記号 #, 太字 ** などの除去
        text = text.replacingOccurrences(of: "[#*~_>`]", with: "", options: .regularExpression)

        // URLの除去
        text = text.replacingOccurrences(of: "https?://[^\\s]+", with: "リンク", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
