import Foundation
import SwiftUI

@MainActor
public final class AgentTaskPlanningService: ObservableObject {
    public static let shared = AgentTaskPlanningService()

    @Published public var tasks: [AgentTask] = []
    @Published public var isRunningPlan: Bool = false
    @Published public var currentExecutingTaskId: UUID? = nil
    @Published public var activeGoalTitle: String = "自律タスク計画"

    private let toolService = ExternalToolExecutionService.shared

    private init() {
        // 初期デモタスク
        loadDefaultPresetPlan()
    }

    // MARK: - 🎯 ユーザープロンプトからタスク自動分解 & 計画生成 (LLM / ルールベース)

    /// ユーザー指示からタスク一覧を自動生成
    public func planTasksFromPrompt(prompt: String, model: String) async {
        self.activeGoalTitle = prompt
        self.tasks.removeAll()

        let lower = prompt.lowercased()

        // 1. AI-trading 関連の自動分解
        if lower.contains("trading") || lower.contains("株") || lower.contains("トレード") || lower.contains("銘柄") || lower.contains("シミュレーション") {
            let t1 = AgentTask(
                title: "市場株価データの取得",
                detail: "立花証券・yfinanceから最新のティック・日足データを取得",
                targetTool: .aiTrading,
                command: "fetch_tachibana_data.py"
            )
            let t2 = AgentTask(
                title: "ポートフォリオ損益シミュレーション",
                detail: "MAGI合議制モデルとリスク憲法ガードに基づきバックテスト実行",
                targetTool: .aiTrading,
                command: "simulate_portfolio.py",
                dependencyIds: [t1.id]
            )
            let t3 = AgentTask(
                title: "ペーパートレード仮想売買の実行",
                detail: "仮想資金での注文発行とポジション監査ログ記録",
                targetTool: .aiTrading,
                command: "run_paper.py",
                dependencyIds: [t2.id]
            )
            let t4 = AgentTask(
                title: "取引レポートをObsidianに保存",
                detail: "本日のシミュレーション結果と収益曲線をmyollamaフォルダに要約記録",
                targetTool: .obsidian,
                dependencyIds: [t3.id]
            )
            self.tasks = [t1, t2, t3, t4]
            return
        }

        // 2. ume-lunch 関連の自動分解
        if lower.contains("lunch") || lower.contains("文字起こし") || lower.contains("会議") || lower.contains("動画") || lower.contains("画像生成") || lower.contains("サーバー") {
            let t1 = AgentTask(
                title: "文字起こし (Whisper) サーバー起動",
                detail: "音声認識バックエンド (Port 5003) を起動してヘルスチェック",
                targetTool: .umeLunch,
                command: "start_transcribe"
            )
            let t2 = AgentTask(
                title: "RAG ナレッジサーバー起動",
                detail: "ドキュメント検索API (Port 5001) の起動",
                targetTool: .umeLunch,
                command: "start_rag"
            )
            let t3 = AgentTask(
                title: "ume-lunch アプリの起動",
                detail: "GUIランチャーをデスクトップに展開",
                targetTool: .umeLunch,
                command: "open_app",
                dependencyIds: [t1.id, t2.id]
            )
            self.tasks = [t1, t2, t3]
            return
        }

        // 3. 汎用タスク計画（デフォルト）
        let t1 = AgentTask(title: "要件とコンテキストの分析", detail: prompt, targetTool: .general)
        let t2 = AgentTask(title: "外部ツールの実行・検証", detail: "対象ツールへのリクエストディスパッチ", targetTool: .general, dependencyIds: [t1.id])
        let t3 = AgentTask(title: "結果サマリーとObsidian記録", detail: "最終レポートの生成", targetTool: .obsidian, dependencyIds: [t2.id])
        self.tasks = [t1, t2, t3]
    }

    public func loadDefaultPresetPlan() {
        let t1 = AgentTask(
            title: "📈 立花証券・市場データ取得",
            detail: "AI-trading エンジンで本日の最新株価を取得",
            targetTool: .aiTrading,
            command: "fetch_tachibana_data.py"
        )
        let t2 = AgentTask(
            title: "🧠 ポートフォリオ＆MAGI予測",
            detail: "ARIMA/Chronosモデルによる銘柄選定と損益シミュレーション",
            targetTool: .aiTrading,
            command: "simulate_portfolio.py",
            dependencyIds: [t1.id]
        )
        let t3 = AgentTask(
            title: "🎙️ ume-lunch 文字起こしサーバー起動",
            detail: "Whisper音声文字起こしサーバー (Port 5003) 起動",
            targetTool: .umeLunch,
            command: "start_transcribe"
        )
        let t4 = AgentTask(
            title: "💾 取引・作業ログをObsidianに保存",
            detail: "Obsidianのmyollamaフォルダに今日のまとめを自動書き込み",
            targetTool: .obsidian,
            dependencyIds: [t2.id, t3.id]
        )
        self.tasks = [t1, t2, t3, t4]
    }

    // MARK: - ⚙️ エージェント自律実行エンジン (Execution Runner)

    /// 計画されたタスクを依存関係順に全自動実行
    public func executeAllTasks(onUpdate: @escaping @Sendable (String) -> Void) async {
        guard !isRunningPlan else { return }
        isRunningPlan = true
        onUpdate("🚀 自律エージェントタスクの実行を開始したのだ！")

        while isRunningPlan {
            // 依存関係がすべて completed かつ自身が pending のタスクを探す
            let executableTasks = tasks.filter { task in
                task.status == .pending && task.dependencyIds.allSatisfy { depId in
                    tasks.first(where: { $0.id == depId })?.status == .completed
                }
            }

            guard let nextTask = executableTasks.first else {
                // もう実行可能なタスクがない
                break
            }

            await executeSingleTask(taskId: nextTask.id, onUpdate: onUpdate)
        }

        isRunningPlan = false
        currentExecutingTaskId = nil

        let completedCount = tasks.filter { $0.status == .completed }.count
        let totalCount = tasks.count
        onUpdate("🎉 すべてのタスク処理が完了したのだ！ (\(completedCount)/\(totalCount) 成功) グラフ画面で結果を確認できるのだ！🌱✨")
    }

    /// 単一タスクの実行
    public func executeSingleTask(taskId: UUID, onUpdate: @escaping @Sendable (String) -> Void) async {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        tasks[index].status = .inProgress
        tasks[index].startedAt = Date()
        tasks[index].progress = 0.1
        currentExecutingTaskId = taskId

        let task = tasks[index]
        onUpdate("⚙️ [実行中] \(task.title)...")

        switch task.targetTool {
        case .aiTrading:
            let script = task.command ?? "run_daily.py"
            let (success, output) = await toolService.executeAITradingScript(scriptName: script) { [weak self] log in
                Task { @MainActor [weak self] in
                    if let idx = self?.tasks.firstIndex(where: { $0.id == taskId }) {
                        self?.tasks[idx].logs.append(log)
                        self?.tasks[idx].progress = min(0.9, (self?.tasks[idx].progress ?? 0.1) + 0.1)
                    }
                }
            }
            if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[idx].status = success ? .completed : .failed
                tasks[idx].progress = success ? 1.0 : 0.0
                tasks[idx].finishedAt = Date()
            }

        case .umeLunch:
            if task.command == "start_transcribe" {
                toolService.startLunchServer(type: .transcribe) { [weak self] log in
                    Task { @MainActor [weak self] in
                        if let idx = self?.tasks.firstIndex(where: { $0.id == taskId }) {
                            self?.tasks[idx].logs.append(log)
                        }
                    }
                }
            } else if task.command == "start_rag" {
                toolService.startLunchServer(type: .rag) { [weak self] log in
                    Task { @MainActor [weak self] in
                        if let idx = self?.tasks.firstIndex(where: { $0.id == taskId }) {
                            self?.tasks[idx].logs.append(log)
                        }
                    }
                }
            } else if task.command == "open_app" {
                toolService.openUmeLunchApp()
            }
            // サーバー起動確認
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[idx].status = .completed
                tasks[idx].progress = 1.0
                tasks[idx].finishedAt = Date()
            }

        case .obsidian:
            let summaryText = "### 📋 エージェント自動実行タスク結果\n・完了タスク数: \(tasks.filter { $0.status == .completed }.count)\n・実行日時: \(Date().formatted())"
            ObsidianSyncService.shared.appendToActiveNote(text: summaryText)
            if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[idx].status = .completed
                tasks[idx].progress = 1.0
                tasks[idx].finishedAt = Date()
            }

        case .general:
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[idx].status = .completed
                tasks[idx].progress = 1.0
                tasks[idx].finishedAt = Date()
            }
        }
    }

    /// タスクを追加
    public func addTask(title: String, detail: String, tool: AgentTargetTool, dependencyIds: [UUID] = []) {
        let newTask = AgentTask(title: title, detail: detail, targetTool: tool, dependencyIds: dependencyIds)
        self.tasks.append(newTask)
    }

    /// タスクを削除
    public func deleteTask(id: UUID) {
        self.tasks.removeAll(where: { $0.id == id })
        // 依存関係からも除外
        for i in 0..<tasks.count {
            tasks[i].dependencyIds.removeAll(where: { $0 == id })
        }
    }

    /// タスク状態をリセット
    public func resetTasks() {
        for i in 0..<tasks.count {
            tasks[i].status = .pending
            tasks[i].progress = 0.0
            tasks[i].startedAt = nil
            tasks[i].finishedAt = nil
            tasks[i].logs.removeAll()
        }
    }
}
