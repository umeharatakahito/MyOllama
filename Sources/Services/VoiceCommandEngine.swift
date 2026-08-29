import Foundation

public enum VoiceAction: Equatable {
    case resetChat
    case compressContext
    case saveToObsidian
    case syncObsidianLatest
    case clearObsidianSync
    case runAgentPlan
    case stopSpeaking
    case enableThinking
    case disableThinking
    case enableRAG
    case disableRAG
    case switchMode(TaskCommandMode)
}

public struct VoiceCommandEngine {
    /// チャットリセット系フレーズ
    private static let resetPatterns = [
        "チャットをリセットして", "チャットをリセット", "チャットリセット", "リセットして", "リセット",
        "会話をリセットして", "会話をリセット", "履歴をリセットして", "履歴をリセット",
        "チャットを消して", "会話を消して", "履歴を消して", "チャットクリア", "クリアして",
        "最初からやり直して", "最初から", "会話を新しくして", "新しく会話を始めて", "全部忘れて"
    ]

    /// エージェントタスク実行系フレーズ
    private static let agentRunPatterns = [
        "タスクを実行して", "タスク実行", "すべてのタスクを実行して", "todoを実行して", "エージェント実行",
        "株取引を実行して", "株のシミュレーションを実行して", "ペーパートレードを実行して", "ルーチンを実行して"
    ]

    /// コンテキスト圧縮・要約メモリ化系フレーズ
    private static let compressPatterns = [
        "コンテキスト圧縮して", "コンテキストを圧縮して", "コンテキスト圧縮", "コンテキストを圧縮",
        "会話を圧縮して", "会話を圧縮", "履歴を圧縮して", "履歴を圧縮",
        "要約してメモリに入れて", "要約してメモリに保存して", "記憶にまとめて", "記憶をまとめて",
        "これまでの会話をまとめて", "これまでの会話を要約して", "大事なことだけ覚えて", "会話を整理して",
        "覚えておいて", "覚えてて", "記憶して", "私の性格をメモして", "性格を覚えて", "好みや性格を記憶して",
        "今の会話を覚えて", "記憶を更新して", "メモリに保存して", "メモリーに保存して"
    ]

    /// Obsidian 保存系フレーズ
    private static let obsidianSavePatterns = [
        "obsidianに保存して", "オブシディアンに保存して", "obsidianにまとめて", "オブシディアンにまとめて",
        "ノートに保存して", "ノートにまとめて", "会話を保存して", "会話をノートに保存して", "mdに保存して", "まとめを保存して"
    ]

    /// Obsidian 同期・壁打ち系フレーズ
    private static let obsidianSyncPatterns = [
        "obsidianの最新ノートを読んで", "obsidianのノートを読んで", "最新のノートを読んで",
        "obsidianと同期して", "ノートと同期して", "今のノートで壁打ちして", "今のノートについてブレストして",
        "obsidianのノートで壁打ちして", "最新ノートを読み込んで", "obsidianを同期して", "壁打ちモードにして"
    ]
    private static let obsidianSyncClearPatterns = [
        "壁打ちを終了して", "ノートの同期を解除して", "ノートの連携をやめて", "obsidianの同期を解除して"
    ]

    /// 読み上げ停止系フレーズ
    private static let stopSpeakingPatterns = [
        "ストップ", "喋るのやめて", "読み上げを止めて", "読み上げ停止", "ストップして", "静かにして", "黙って"
    ]

    /// 思考モード切替
    private static let enableThinkingPatterns = ["思考モードをオンにして", "思考モードを有効にして", "思考をオンにして", "思考オン"]
    private static let disableThinkingPatterns = ["思考モードをオフにして", "思考モードを無効にして", "思考をオフにして", "思考オフ"]

    /// RAG切替
    private static let enableRAGPatterns = ["ragをオンにして", "知識ベースをオンにして", "ragを有効にして"]
    private static let disableRAGPatterns = ["ragをオフにして", "知識ベースをオフにして", "ragを無効にして"]

    /// モード切替フレーズ
    private static let brainstormPatterns = ["ブレストモード", "ブレインストーミング", "ブレストで", "アイデア出しモード", "壁打ちモード"]
    private static let planningPatterns = ["企画モード", "企画書モード", "仕様策定モード", "企画を作って", "仕様書モード"]
    private static let academicPatterns = ["論文モード", "研究モード", "学術モード", "論文を考えて", "論文を書いて"]
    private static let reviewPatterns = ["レビューモード", "コードレビュー", "添削モード", "推敲モード", "批判的レビュー"]
    private static let normalPatterns = ["通常モード", "普通モード", "通常会話に戻して", "普通の会話"]

    /// 入力テキストから音声コマンドを検知
    public static func detectCommand(from rawText: String) -> VoiceAction? {
        let text = rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "！", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: "、", with: "")
            .replacingOccurrences(of: " ", with: "")

        // 1. チャットリセット
        for p in resetPatterns {
            if text == p.lowercased() || text.hasPrefix(p.lowercased()) {
                return .resetChat
            }
        }

        // 2. エージェントタスク実行
        for p in agentRunPatterns {
            if text == p.lowercased() || text.contains(p.lowercased()) {
                return .runAgentPlan
            }
        }

        // 2. Obsidian 同期 & 保存
        for p in obsidianSyncClearPatterns {
            if text == p.lowercased() || text.contains(p.lowercased()) {
                return .clearObsidianSync
            }
        }
        for p in obsidianSyncPatterns {
            if text == p.lowercased() || text.contains(p.lowercased()) {
                return .syncObsidianLatest
            }
        }
        for p in obsidianSavePatterns {
            if text == p.lowercased() || text.contains(p.lowercased()) {
                return .saveToObsidian
            }
        }

        // 3. コンテキスト圧縮
        for p in compressPatterns {
            if text == p.lowercased() || text.contains(p.lowercased()) {
                return .compressContext
            }
        }

        // 4. 読み上げ停止
        for p in stopSpeakingPatterns {
            if text == p.lowercased() {
                return .stopSpeaking
            }
        }

        // 4. モード切替
        for p in brainstormPatterns where text.contains(p) {
            if let mode = TaskCommandMode.allModes.first(where: { $0.id == "brainstorm" }) {
                return .switchMode(mode)
            }
        }
        for p in planningPatterns where text.contains(p) {
            if let mode = TaskCommandMode.allModes.first(where: { $0.id == "planning" }) {
                return .switchMode(mode)
            }
        }
        for p in academicPatterns where text.contains(p) {
            if let mode = TaskCommandMode.allModes.first(where: { $0.id == "academic" }) {
                return .switchMode(mode)
            }
        }
        for p in reviewPatterns where text.contains(p) {
            if let mode = TaskCommandMode.allModes.first(where: { $0.id == "review" }) {
                return .switchMode(mode)
            }
        }
        for p in normalPatterns where text.contains(p) {
            return .switchMode(TaskCommandMode.defaultMode)
        }

        // 5. 思考モード
        for p in enableThinkingPatterns where text.contains(p) { return .enableThinking }
        for p in disableThinkingPatterns where text.contains(p) { return .disableThinking }

        // 6. RAG
        for p in enableRAGPatterns where text.contains(p) { return .enableRAG }
        for p in disableRAGPatterns where text.contains(p) { return .disableRAG }

        return nil
    }
}
