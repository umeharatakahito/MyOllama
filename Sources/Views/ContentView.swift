import SwiftUI

public struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var floatingController = FloatingMascotController.shared
    @State private var showSettings: Bool = false
    @State private var showContextInspector: Bool = false
    @State private var showOpenNotebook: Bool = false
    @State private var showVoiceHelp: Bool = false
    @State private var showMemoryManager: Bool = false
    @State private var showAgentWorkspace: Bool = false
    @State private var showVocabularyList: Bool = false
    @State private var initialWorkspaceTab: AgentWorkspaceModalView.WorkspaceTab = .tasks
    @State private var selectedSettingsTab: SettingsTab = .persona
    @AppStorage("MyOllama.AlwaysOnTop") private var isAlwaysOnTop: Bool = false
    @AppStorage("MyOllama.Show3DMascot") private var show3DMascot: Bool = true

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case persona = "🎭 ペルソナ"
        case memory = "🧠 メモリ"
        case rag = "📚 RAG"
        case voice = "🔊 音声"
        case general = "⚙️ 全般"

        public var id: String { rawValue }
    }

    public init(viewModel: ChatViewModel? = nil) {
        self.viewModel = viewModel ?? ChatViewModel()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Error Banner
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("再試行") {
                        Task { await viewModel.loadModels() }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Obsidian Wall-Hitting Active Banner
            if let activeTitle = ObsidianSyncService.shared.activeNoteTitle,
               ObsidianSyncService.shared.isSyncingWithObsidian {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(.cyan)
                    Text("【Obsidian壁打ち連携中】")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("「\(activeTitle).md」の内容をずんだもんが把握しています。Obsidianを見ながら音声で壁打ちできます。")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button("再同期") {
                        _ = ObsidianSyncService.shared.syncLatestObsidianNote()
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("解除") {
                        ObsidianSyncService.shared.clearSync()
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.cyan.opacity(0.3)),
                    alignment: .bottom
                )
            }

            // Chat Messages / Welcome Area with 3D Mascot Overlay
            ZStack(alignment: .bottomTrailing) {
                if viewModel.messages.isEmpty {
                    welcomeView
                } else {
                    messageListView
                }

                // 3D Zundamon Mascot Overlay (フローティング非表示時のみチャット内に表示)
                if show3DMascot && !floatingController.isVisible && (viewModel.selectedPersonaId == "zundamon" || viewModel.isVoicevoxEnabled) {
                    Zundamon3DView(viewModel: viewModel)
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }

            Divider()

            // Bottom Input
            ChatInputView(
                viewModel: viewModel,
                onInspectContext: { showContextInspector = true },
                onOpenRAG: { showOpenNotebook = true },
                onOpenVoiceHelp: { showVoiceHelp = true }
            )
        }
        .frame(minWidth: 640, minHeight: 520)
        .sheet(isPresented: $showSettings) {
            settingsModalView
        }
        .sheet(isPresented: $showContextInspector) {
            ContextInspectorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showOpenNotebook) {
            OpenNotebookView()
        }
        .sheet(isPresented: $showVoiceHelp) {
            VoiceCommandsHelpView()
        }
        .sheet(isPresented: $showMemoryManager) {
            MemoryManagerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showAgentWorkspace) {
            AgentWorkspaceModalView(viewModel: viewModel, initialTab: initialWorkspaceTab)
        }
        .sheet(isPresented: $showVocabularyList) {
            VocabularyListView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MyOllama.RequestEnglishAnalysis"))) { notif in
            if let text = notif.object as? String {
                viewModel.requestEnglishAnalysis(text: text)
            }
        }
        .onAppear {
            updateWindowLevel()
        }
        .onChange(of: isAlwaysOnTop) { _, _ in
            updateWindowLevel()
        }
        .onChange(of: viewModel.speechRecognizer.isRecording) { _, isRec in
            if isRec && show3DMascot {
                floatingController.show(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.speechRecognizer.isAlwaysListening) { _, isListening in
            if isListening && show3DMascot {
                floatingController.show(viewModel: viewModel)
            }
        }
    }

    private func updateWindowLevel() {
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.level = isAlwaysOnTop ? .floating : .normal
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Status & Model Picker
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : (viewModel.isLoadingModels ? Color.orange : Color.red))
                    .frame(width: 9, height: 9)

                if viewModel.isLoadingModels {
                    Text("接続中...")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else if viewModel.availableModels.isEmpty {
                    Text("モデルが見つかりません")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Picker("モデル:", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels) { model in
                            HStack {
                                if model.isVisionSupported {
                                    Text("👁️ \(model.name)")
                                } else {
                                    Text(model.name)
                                }
                                if !model.formattedSize.isEmpty {
                                    Text("(\(model.formattedSize))")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(model.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 240)
                }
            }

            // Persona Quick Selector Badge
            Menu {
                ForEach(PersonaPreset.presets) { preset in
                    Button(action: {
                        withAnimation {
                            viewModel.selectPersona(preset)
                        }
                    }) {
                        HStack {
                            Image(systemName: preset.systemImage)
                            Text(preset.name)
                            if viewModel.selectedPersonaId == preset.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.currentPersona.systemImage)
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text(viewModel.currentPersona.name)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("クリックしてペルソナ（役割）を変更")

            Spacer(minLength: 8)

            // Toolbar Action Buttons (Locked to slim horizontal bar, never vertically stretches)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    // Open Notebook / RAG Button
                    Button(action: {
                        showOpenNotebook = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text("RAG / ノート")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.cyan.opacity(0.12))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Open Notebook (ume-lunch) のRAGナレッジとObsidianノート一覧を閲覧・検索")

                    // Context Inspector Button
                    Button(action: {
                        showContextInspector = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 11))
                            Text("コンテキスト")
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("LLMに渡される直前のコンテキスト（システムプロンプト・メモリ・履歴）を確認")

                    // Memory Manager Button
                    Button(action: {
                        showMemoryManager = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 11))
                            Text("メモリー")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("あなたの性格・好み・重要事項・会話の長期記憶を管理・抽出")

                    // Voice Commands Cheat Sheet Button
                    Button(action: {
                        showVoiceHelp = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.badge.waveform")
                                .foregroundColor(.purple)
                                .font(.system(size: 11))
                            Text("音声コマンド")
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("音声コマンド・自動送信トリガーの一覧を確認")

                    // Agent Task Manager Button
                    Button(action: {
                        initialWorkspaceTab = .tasks
                        showAgentWorkspace = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .foregroundColor(.indigo)
                                .font(.system(size: 11))
                            Text("タスク")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("エージェントのTODOタスク一覧と実行状況を確認")

                    // Agent Graph & Metrics Button
                    Button(action: {
                        initialWorkspaceTab = .graph
                        showAgentWorkspace = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .foregroundColor(.pink)
                                .font(.system(size: 11))
                            Text("グラフ")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.pink.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("タスクフロー依存関係DAGグラフと進行度・ツール稼働統計チャートを表示")

                    // English Vocabulary List Button
                    Button(action: {
                        showVocabularyList = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "character.book.closed.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text("単語帳")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("英語学習単語帳（発音・習得チェック・Obsidian保存）を表示")

                    // Obsidian Wall-Hitting Sync Button
                    Button(action: {
                        withAnimation {
                            if ObsidianSyncService.shared.isSyncingWithObsidian {
                                ObsidianSyncService.shared.clearSync()
                            } else {
                                _ = ObsidianSyncService.shared.syncLatestObsidianNote()
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: ObsidianSyncService.shared.isSyncingWithObsidian ? "book.pages.fill" : "book.closed")
                                .foregroundColor(ObsidianSyncService.shared.isSyncingWithObsidian ? .cyan : .primary)
                                .font(.system(size: 11))
                            Text(ObsidianSyncService.shared.isSyncingWithObsidian ? "Obsidian連携中" : "Obsidian壁打ち")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(ObsidianSyncService.shared.isSyncingWithObsidian ? .cyan : .primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(ObsidianSyncService.shared.isSyncingWithObsidian ? Color.cyan.opacity(0.18) : Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Obsidianで開いている最新ノートを自動読み込みし、Obsidian画面を見ながらずんだもんと壁打ち対話します")

                    // 3D Zundamon Mascot Toggle (Floating & In-app)
                    Button(action: {
                        withAnimation {
                            show3DMascot.toggle()
                            if show3DMascot {
                                FloatingMascotController.shared.show(viewModel: viewModel)
                            } else {
                                FloatingMascotController.shared.hide()
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: show3DMascot ? "cube.transparent.fill" : "cube.transparent")
                                .foregroundColor(show3DMascot ? .green : .secondary)
                                .font(.system(size: 11))
                            Text("3D")
                                .font(.system(size: 11))
                                .foregroundColor(show3DMascot ? .green : .secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(show3DMascot ? Color.green.opacity(0.18) : Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("画面上に常に最前面で浮遊する3Dずんだもん（クリックでMyOllamaを表示）を切り替え")

                    // Always on Top (Pin) Button
                    Button(action: {
                        withAnimation {
                            isAlwaysOnTop.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                                .foregroundColor(isAlwaysOnTop ? .orange : .primary)
                                .font(.system(size: 11))
                            Text(isAlwaysOnTop ? "最前面" : "通常")
                                .font(.system(size: 11))
                                .foregroundColor(isAlwaysOnTop ? .orange : .primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(isAlwaysOnTop ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isAlwaysOnTop ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("ウィンドウを常に手前（最前面）に固定表示します")

                    // Obsidian Save Button
                    Button(action: {
                        Task {
                            let (success, fileName) = await viewModel.saveCurrentChatToObsidian()
                            if success, let name = fileName {
                                viewModel.errorMessage = "✅ 会話を Obsidian の myollama フォルダに「\(name)」として保存しました！"
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text("Obsidian保存")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 26)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .disabled(viewModel.messages.isEmpty)
                    .help("現在の会話ログをまとめ付きで Obsidian の myollama フォルダに .md ファイルとして保存")

                    Button(action: {
                        Task { await viewModel.loadModels() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .help("モデル一覧を再読み込み")

                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .help("設定 (プロンプト・ロール・メモリ・音声・RAG)")

                    Button(action: { viewModel.clearChat() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.messages.isEmpty)
                    .help("チャットをクリア")
                }
                .frame(height: 28)
            }
            .frame(height: 30)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(height: 42)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Welcome View (Prompt Engineering Studio & 7R / RCTF Dashboard)
    private var welcomeView: some View {
        PromptEngineeringDashboardView(
            viewModel: viewModel,
            onOpenMemory: { showMemoryManager = true },
            onOpenRAG: { showOpenNotebook = true }
        )
    }

    // MARK: - Message List View
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Tabbed Settings Modal View
    private var settingsModalView: some View {
        VStack(spacing: 0) {
            // Header with tabs
            HStack {
                Picker("", selection: $selectedSettingsTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 420)

                Spacer()

                Button("閉じる") {
                    showSettings = false
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tab Contents
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSettingsTab {
                    case .persona:
                        personaSettingsSection
                    case .memory:
                        memorySettingsSection
                    case .rag:
                        ragSettingsSection
                    case .voice:
                        voiceSettingsSection
                    case .general:
                        generalSettingsSection
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - Settings Sections
    private var personaSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🎭 ペルソナプリセット")
                    .font(.headline)
                Text("AIの役割・キャラクターを選択します。選択するとシステムプロンプトが自動設定されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(PersonaPreset.presets) { preset in
                        Button(action: {
                            withAnimation {
                                viewModel.selectPersona(preset)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: preset.systemImage)
                                    .font(.system(size: 16))
                                Text(preset.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedPersonaId == preset.id ? Color.purple.opacity(0.18) : Color.primary.opacity(0.04))
                            .foregroundColor(viewModel.selectedPersonaId == preset.id ? .purple : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(viewModel.selectedPersonaId == preset.id ? Color.purple.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Role Names
            VStack(alignment: .leading, spacing: 8) {
                Text("👤 ロール・呼び名の設定")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ユーザーの呼び名 (あなた):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("例: たかひと, マスター", text: $viewModel.userName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AIの名前・役割名:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("例: ずんだもん, アシスタント", text: $viewModel.assistantName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Divider()

            // System Prompt Editor
            VStack(alignment: .leading, spacing: 6) {
                Text("📝 システムプロンプト")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("AIの口調、禁止事項、出力形式などを直接編集できます。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $viewModel.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }

    private var memorySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🧠 長期記憶 (Memory Notes)")
                    .font(.headline)
                Text("AIが常に覚えておくべき情報（ユーザーの専門分野、使用言語、好みのフォーマット、環境など）を設定します。すべての会話に自動挿入されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $viewModel.memoryNotes)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )

                Text("例:\n・ユーザーはMacBook Pro (Apple Silicon) を使用している\n・Swift, TypeScript, Pythonでの開発を好む\n・簡潔な回答と丁寧な敬語を好む")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("⏳ 会話コンテキスト保持数:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("直近 \(viewModel.contextHistoryLimit) 往復 (\(viewModel.contextHistoryLimit * 2) 件)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(viewModel.contextHistoryLimit) },
                    set: { viewModel.contextHistoryLimit = Int($0) }
                ), in: 2...30, step: 1)

                Text("Ollamaに送信する直近の会話履歴の件数です。件数を減らすと生成が高速になり、メモリ消費を抑えられます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var ragSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "book.pages.fill")
                    .foregroundColor(.cyan)
                Text("Open Notebook (RAG) 設定")
                    .font(.headline)
                Spacer()
                if viewModel.openNotebook.isServerRunning {
                    Text("API 稼働中 (5055)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                } else {
                    Text("API 停止中 (ローカル検索で動作)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }

            Toggle("会話時にRAG知識ベースを自動検索して回答に活用する", isOn: $viewModel.isRAGEnabled)
                .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("💎 Obsidian Vault 連携:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("取り込み元: \(OpenNotebookService.defaultObsidianVaultPath)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("検出されたファイル数: \(viewModel.openNotebook.obsidianNotes.count) 件")
                    .font(.caption)
                    .foregroundColor(.primary)

                Button("Open Notebook ナレッジ画面を開く") {
                    showSettings = false
                    showOpenNotebook = true
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
    }

    private var voiceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.green)
                Text("VOICEVOX（ずんだもん）音声設定")
                    .font(.headline)
                Spacer()
                if viewModel.voicevox.isAvailable {
                    Text("接続中 (0.25.2)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                } else {
                    Text("未接続")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }
            }

            Toggle("AIの返答完了時に自動で読み上げる", isOn: $viewModel.isVoicevoxEnabled)
                .font(.callout)

            if viewModel.isVoicevoxEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("スタイル:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Picker("", selection: $viewModel.zundamonStyleId) {
                            ForEach(ZundamonStyle.allStyles) { style in
                                Text(style.name).tag(style.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)

                        Button("テスト再生") {
                            viewModel.speakMessage("ボクはずんだもんなのだ！よろしくなのだ！")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    HStack(spacing: 12) {
                        Text("話速 (\(String(format: "%.1fx", viewModel.voiceSpeedScale))):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Slider(value: $viewModel.voiceSpeedScale, in: 0.8...1.6, step: 0.1)
                            .frame(maxWidth: 200)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⚙️ モデル＆推論オプション")
                .font(.headline)

            Toggle("思考プロセス (think) を有効化", isOn: $viewModel.enableThinking)
                .font(.subheadline)
            Text("QwenやDeepSeekなどの推論モデルに対して思考出力を要求し、折りたたみアコーディオンで表示します。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("💡 ヒント")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("・Enterキーで送信、Shift+Enterで改行できます。\n・Cmd+V でスクリーンショットやFinderの画像を即座に貼り付けできます。\n・マイクボタンを押すとMacの音声認識で手軽にテキスト入力できます。\n・RAGをONにすると、Obsidian等の知識を自動検索して回答に引用します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
