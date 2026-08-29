import Foundation
import AppKit

public enum LunchServerType: String, CaseIterable, Identifiable, Sendable {
    case transcribe = "文字起こし (Whisper)"
    case rag = "RAG ナレッジ検索"
    case image = "画像生成 (FLUX/SD)"
    case video = "動画生成 (SVD)"
    case youtube = "YouTube 連携"

    public var id: String { rawValue }

    public var scriptName: String {
        switch self {
        case .transcribe: return "transcribe_server.py"
        case .rag: return "rag_server.py"
        case .image: return "image_server.py"
        case .video: return "video_server.py"
        case .youtube: return "youtube_server.py"
        }
    }

    public var defaultPort: Int {
        switch self {
        case .transcribe: return 5003
        case .rag: return 5001
        case .image: return 5002
        case .video: return 5004
        case .youtube: return 5005
        }
    }

    public var icon: String {
        switch self {
        case .transcribe: return "waveform.badge.mic"
        case .rag: return "doc.text.magnifyingglass"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .youtube: return "play.tv.fill"
        }
    }
}

@MainActor
public final class ExternalToolExecutionService: ObservableObject {
    public static let shared = ExternalToolExecutionService()

    public static let aiTradingDir = "/Users/\(NSUserName())/program/AI-trading"
    public static let aiTradingPython = "/Users/\(NSUserName())/program/AI-trading/.venv/bin/python"
    public static let umeLunchDir = "/Users/\(NSUserName())/program/ume-Lunch/ume-lunch"
    public static let umeLunchPythonDir = "/Users/\(NSUserName())/program/ume-Lunch/ume-lunch/python"

    @Published public var runningProcesses: [String: Process] = [:]
    @Published public var serverStatuses: [LunchServerType: Bool] = [:]

    private init() {
        Task {
            await checkAllLunchServersHealth()
        }
    }

    // MARK: - 📈 AI-trading Engine Execution Methods

    /// AI-trading スクリプトを実行してリアルタイムにログと結果を取得
    public func executeAITradingScript(
        scriptName: String,
        arguments: [String] = [],
        onLog: @escaping @Sendable (String) -> Void
    ) async -> (success: Bool, output: String) {
        let tradingDir = Self.aiTradingDir
        let scriptPath = "\(tradingDir)/scripts/\(scriptName)"
        let pythonPath = FileManager.default.fileExists(atPath: Self.aiTradingPython) ? Self.aiTradingPython : "/usr/bin/python3"

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            let errorMsg = "❌ スクリプトが見つかりません: \(scriptPath)"
            onLog(errorMsg)
            return (false, errorMsg)
        }

        onLog("🚀 [AI-trading] \(scriptName) を開始中...")

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: pythonPath)
                proc.arguments = [scriptPath] + arguments
                proc.currentDirectoryURL = URL(fileURLWithPath: tradingDir)

                var env = ProcessInfo.processInfo.environment
                env["PYTHONUNBUFFERED"] = "1"
                env["PYTHONPATH"] = "\(tradingDir):\(tradingDir)/engine"
                proc.environment = env

                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let fullOutput = String(data: data, encoding: .utf8) ?? ""
                    proc.waitUntilExit()

                    let success = (proc.terminationStatus == 0)
                    let statusMsg = success ? "✅ [AI-trading] \(scriptName) が正常終了しました" : "❌ [AI-trading] 終了コード: \(proc.terminationStatus)"
                    DispatchQueue.main.async {
                        onLog(fullOutput)
                        onLog(statusMsg)
                        continuation.resume(returning: (success, fullOutput))
                    }
                } catch {
                    let errStr = "❌ プロセス起動エラー: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        onLog(errStr)
                        continuation.resume(returning: (false, errStr))
                    }
                }
            }
        }
    }

    /// ペーパートレード仮想売買を実行
    public func runPaperTrade(onLog: @escaping @Sendable (String) -> Void) async -> (success: Bool, output: String) {
        await executeAITradingScript(scriptName: "run_paper.py", onLog: onLog)
    }

    /// 日次ルーチン（データ取得・シミュレーション・レポート）を実行
    public func runDailyRoutine(onLog: @escaping @Sendable (String) -> Void) async -> (success: Bool, output: String) {
        await executeAITradingScript(scriptName: "run_daily.py", onLog: onLog)
    }

    /// 株価データ取得（立花証券 / yfinance / J-Quants）
    public func fetchMarketData(source: String = "tachibana", onLog: @escaping @Sendable (String) -> Void) async -> (success: Bool, output: String) {
        let script = (source == "yfinance") ? "fetch_yfinance.py" : ((source == "jquants") ? "fetch_jquants.py" : "fetch_tachibana_data.py")
        return await executeAITradingScript(scriptName: script, onLog: onLog)
    }

    /// ポートフォリオ損益シミュレーションを実行
    public func simulatePortfolio(onLog: @escaping @Sendable (String) -> Void) async -> (success: Bool, output: String) {
        await executeAITradingScript(scriptName: "simulate_portfolio.py", onLog: onLog)
    }

    // MARK: - 🍱 ume-lunch Server Execution Methods

    /// ume-lunch の指定サーバーを起動
    public func startLunchServer(type: LunchServerType, onLog: @escaping @Sendable (String) -> Void) {
        guard runningProcesses[type.rawValue] == nil else {
            onLog("⚠️ \(type.rawValue) サーバーは既に起動しています")
            return
        }

        let pythonDir = Self.umeLunchPythonDir
        let scriptPath = "\(pythonDir)/\(type.scriptName)"
        let pythonPath = "/usr/bin/python3"

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            onLog("❌ サーバーファイルが見つかりません: \(scriptPath)")
            return
        }

        onLog("🚀 [ume-lunch] \(type.rawValue) サーバーを起動中 (Port \(type.defaultPort))...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: pythonPath)
            proc.arguments = [scriptPath]
            proc.currentDirectoryURL = URL(fileURLWithPath: pythonDir)

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    onLog("[\(type.rawValue)] \(str)")
                }
            }

            do {
                try proc.run()
                Task { @MainActor [weak self] in
                    self?.runningProcesses[type.rawValue] = proc
                    self?.serverStatuses[type] = true
                }
            } catch {
                DispatchQueue.main.async {
                    onLog("❌ サーバー起動エラー: \(error.localizedDescription)")
                }
            }
        }
    }

    /// ume-lunch の指定サーバーを停止
    public func stopLunchServer(type: LunchServerType) {
        if let proc = runningProcesses[type.rawValue] {
            proc.terminate()
            runningProcesses.removeValue(forKey: type.rawValue)
        }
        serverStatuses[type] = false

        // ポート使用中のプロセスも停止
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProc.arguments = ["-f", type.scriptName]
        try? killProc.run()
    }

    /// 各サーバーの稼働確認（ヘルスチェック）
    public func checkAllLunchServersHealth() async {
        for type in LunchServerType.allCases {
            let isRunning = await checkPortListening(port: type.defaultPort)
            self.serverStatuses[type] = isRunning
        }
    }

    private func checkPortListening(port: Int) async -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    /// ume-lunch アプリ自体を起動
    public func openUmeLunchApp() {
        let appPath = "\(Self.umeLunchDir)/build/ume-lunch.app"
        if FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
        } else {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", "ume-lunch"]
            try? proc.run()
        }
    }
}
