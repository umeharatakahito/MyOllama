import SwiftUI

public struct AgentTaskManagerView: View {
    @ObservedObject var planningService = AgentTaskPlanningService.shared
    @ObservedObject var toolService = ExternalToolExecutionService.shared
    @ObservedObject var viewModel: ChatViewModel

    @State private var showingAddTaskSheet: Bool = false
    @State private var newTitle: String = ""
    @State private var newDetail: String = ""
    @State private var newTool: AgentTargetTool = .aiTrading
    @State private var expandedTaskId: UUID? = nil

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Task List
            ScrollView {
                VStack(spacing: 12) {
                    // Quick Action Presets
                    quickPresetBar

                    if planningService.tasks.isEmpty {
                        emptyTaskState
                    } else {
                        ForEach(planningService.tasks) { task in
                            taskCard(task: task)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            addTaskSheet
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: "checklist")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("📋 エージェントタスク管理")
                    .font(.system(size: 14, weight: .bold))
                Text(planningService.activeGoalTitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Run All Button
            Button(action: {
                Task {
                    await planningService.executeAllTasks { update in
                        Task { @MainActor in
                            viewModel.errorMessage = update
                        }
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: planningService.isRunningPlan ? "hourglass" : "play.fill")
                    Text(planningService.isRunningPlan ? "実行中..." : "🚀 すべて実行")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(planningService.isRunningPlan ? Color.orange : Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(planningService.isRunningPlan || planningService.tasks.isEmpty)

            // Reset Button
            Button(action: {
                planningService.resetTasks()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("タスク状態を未着手にリセット")

            // Add Task Button
            Button(action: {
                showingAddTaskSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("新規タスクを追加")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Quick Presets Bar
    private var quickPresetBar: some View {
        HStack(spacing: 8) {
            Text("🎯 プリセット:")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button("📈 株取引シミュレーション") {
                Task {
                    await planningService.planTasksFromPrompt(prompt: "AI-tradingで最新データを取得しシミュレーションを実行してObsidianに記録", model: viewModel.selectedModel)
                }
            }
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("🎙️ ume-lunch 文字起こし起動") {
                Task {
                    await planningService.planTasksFromPrompt(prompt: "ume-lunchの文字起こしサーバーとRAGサーバーを起動", model: viewModel.selectedModel)
                }
            }
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
    }

    // MARK: - Task Card
    private func taskCard(task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Status Icon
                Image(systemName: task.status.icon)
                    .foregroundColor(task.status.color)
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .bold))

                        // Target Tool Badge
                        HStack(spacing: 3) {
                            Image(systemName: task.targetTool.icon)
                            Text(task.targetTool.rawValue)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.targetTool.color.opacity(0.18))
                        .foregroundColor(task.targetTool.color)
                        .clipShape(Capsule())

                        // Status Badge
                        Text(task.status.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.status.color.opacity(0.12))
                            .foregroundColor(task.status.color)
                            .clipShape(Capsule())
                    }

                    Text(task.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Execute Single Task Button
                Button(action: {
                    Task {
                        await planningService.executeSingleTask(taskId: task.id) { msg in
                            Task { @MainActor in
                                viewModel.errorMessage = msg
                            }
                        }
                    }
                }) {
                    Image(systemName: task.status == .inProgress ? "hourglass" : "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(task.status == .completed ? .secondary : .indigo)
                }
                .buttonStyle(.plain)
                .disabled(planningService.isRunningPlan || task.status == .inProgress)

                // Delete Button
                Button(action: {
                    planningService.deleteTask(id: task.id)
                }) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Progress Bar
            if task.status == .inProgress || task.progress > 0 {
                ProgressView(value: task.progress)
                    .tint(task.status.color)
                    .frame(height: 3)
            }

            // Dependency Indicator
            if !task.dependencyIds.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                    Text("前提タスク:")
                        .font(.system(size: 9, weight: .medium))
                    ForEach(task.dependencyIds, id: \.self) { depId in
                        if let depTask = planningService.tasks.first(where: { $0.id == depId }) {
                            Text(depTask.title)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .foregroundColor(.secondary)
            }

            // Logs Toggle
            if !task.logs.isEmpty {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedTaskId == task.id },
                        set: { isExp in expandedTaskId = isExp ? task.id : nil }
                    )
                ) {
                    ScrollView {
                        Text(task.logs.joined(separator: ""))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                    .frame(maxHeight: 120)
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } label: {
                    Text("実行ログ (\(task.logs.count)行)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(task.status == .inProgress ? Color.blue.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Empty State
    private var emptyTaskState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("現在登録されているタスクはありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("デフォルトプリセットを読み込む") {
                planningService.loadDefaultPresetPlan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Add Task Sheet
    private var addTaskSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("➕ 新規タスクの追加")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("タイトル")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: 最新株価データのダウンロード", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("詳細・指示")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: J-Quants APIから日足データを取得", text: $newDetail)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("対象ツール")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $newTool) {
                    ForEach(AgentTargetTool.allCases) { tool in
                        HStack {
                            Image(systemName: tool.icon)
                            Text(tool.rawValue)
                        }
                        .tag(tool)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    showingAddTaskSheet = false
                }
                .buttonStyle(.bordered)

                Button("追加") {
                    if !newTitle.isEmpty {
                        planningService.addTask(title: newTitle, detail: newDetail, tool: newTool)
                        newTitle = ""
                        newDetail = ""
                        showingAddTaskSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
