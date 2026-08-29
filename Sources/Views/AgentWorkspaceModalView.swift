import SwiftUI

public struct AgentWorkspaceModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: WorkspaceTab = .tasks

    public enum WorkspaceTab: String, CaseIterable, Identifiable {
        case tasks = "📋 タスク一覧 (TODO)"
        case graph = "📈 グラフ & 依存関係"

        public var id: String { rawValue }
    }

    public init(viewModel: ChatViewModel, initialTab: WorkspaceTab = .tasks) {
        self.viewModel = viewModel
        self._selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Modal Top Bar
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.indigo)
                    .font(.system(size: 16))

                Text("エージェント ワークスペース")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                // Tab Switcher
                Picker("", selection: $selectedTab) {
                    ForEach(WorkspaceTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Active Content
            if selectedTab == .tasks {
                AgentTaskManagerView(viewModel: viewModel)
            } else {
                AgentTaskGraphView()
            }
        }
        .frame(minWidth: 700, minHeight: 520)
    }
}
