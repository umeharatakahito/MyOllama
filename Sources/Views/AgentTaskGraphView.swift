import SwiftUI

public struct AgentTaskGraphView: View {
    @ObservedObject var planningService = AgentTaskPlanningService.shared
    @ObservedObject var toolService = ExternalToolExecutionService.shared

    public init() {}

    private var completedCount: Int {
        planningService.tasks.filter { $0.status == .completed }.count
    }

    private var totalCount: Int {
        planningService.tasks.count
    }

    private var progressRatio: Double {
        totalCount == 0 ? 0.0 : Double(completedCount) / Double(totalCount)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Metrics & Progress Gauge
                metricsOverviewCard

                // Interactive Task Dependency DAG Graph (フローノードチャート)
                taskDependencyGraphCard

                // Live Tools & Server Status Monitor
                liveToolsStatusCard
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 1. Top Metrics & Progress Gauge
    private var metricsOverviewCard: some View {
        HStack(spacing: 20) {
            // Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(progressRatio))
                    .stroke(
                        LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.spring(), value: progressRatio)

                VStack(spacing: 0) {
                    Text("\(Int(progressRatio * 100))%")
                        .font(.system(size: 16, weight: .bold))
                    Text("完了")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            // Stat Badges
            VStack(alignment: .leading, spacing: 8) {
                Text("📊 タスク進行状況 & 達成率")
                    .font(.system(size: 14, weight: .bold))

                HStack(spacing: 12) {
                    statBox(title: "全タスク", value: "\(totalCount)", color: .primary)
                    statBox(title: "完了", value: "\(completedCount)", color: .green)
                    statBox(title: "進行中", value: "\(planningService.tasks.filter { $0.status == .inProgress }.count)", color: .blue)
                    statBox(title: "未着手", value: "\(planningService.tasks.filter { $0.status == .pending }.count)", color: .secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 2. Task Dependency DAG Graph (フローノードチャート)
    private var taskDependencyGraphCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundColor(.indigo)
                Text("📈 タスク実行フロー (DAG 依存関係グラフ)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("矢印: 実行順序と依存関係")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if planningService.tasks.isEmpty {
                Text("タスクが存在しません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(planningService.tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 12) {
                            // Left Node Index & Line
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(task.status == .completed ? Color.green : (task.status == .inProgress ? Color.blue : Color.gray.opacity(0.3)))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(task.status == .completed || task.status == .inProgress ? .white : .primary)
                                    )
                                    .shadow(color: task.status.color.opacity(0.4), radius: task.status == .inProgress ? 6 : 0)

                                if index < planningService.tasks.count - 1 {
                                    Rectangle()
                                        .fill(task.status == .completed ? Color.green.opacity(0.6) : Color.gray.opacity(0.25))
                                        .frame(width: 2, height: 36)
                                }
                            }
                            .frame(width: 30)

                            // Node Content Box
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(task.title)
                                            .font(.system(size: 12, weight: .bold))
                                        
                                        HStack(spacing: 3) {
                                            Image(systemName: task.targetTool.icon)
                                            Text(task.targetTool.rawValue)
                                        }
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(task.targetTool.color.opacity(0.18))
                                        .foregroundColor(task.targetTool.color)
                                        .clipShape(Capsule())
                                    }

                                    Text(task.detail)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: task.status.icon)
                                    .foregroundColor(task.status.color)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(task.status == .inProgress ? Color.blue : (task.status == .completed ? Color.green.opacity(0.4) : Color.primary.opacity(0.08)), lineWidth: task.status == .inProgress ? 1.5 : 1)
                            )
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 3. Live Tools & Server Status Monitor
    private var liveToolsStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.orange)
                Text("⚙️ 連携ツール稼働ステータス (Live Monitors)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("再確認") {
                    Task {
                        await toolService.checkAllLunchServersHealth()
                    }
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            VStack(spacing: 8) {
                // AI-trading Status
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        Text("AI-trading Engine")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                    Text("Python 3.13 (.venv 連携済)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // ume-lunch Servers Status Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(LunchServerType.allCases) { server in
                        let isRunning = toolService.serverStatuses[server] ?? false
                        HStack(spacing: 8) {
                            Image(systemName: server.icon)
                                .font(.system(size: 12))
                                .foregroundColor(isRunning ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(server.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                Text("Port \(server.defaultPort)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(isRunning ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 7, height: 7)
                        }
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRunning ? Color.green.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
