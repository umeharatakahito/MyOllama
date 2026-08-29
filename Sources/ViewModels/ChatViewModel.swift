import SwiftUI
import Combine
import AppKit

@MainActor
public final class ChatViewModel: ObservableObject {
    private static let selectedModelKey = "MyOllama.SelectedModel"
    private static let enableThinkingKey = "MyOllama.EnableThinking"
    private static let systemPromptKey = "MyOllama.SystemPrompt"
    private static let selectedPersonaIdKey = "MyOllama.SelectedPersonaId"
    private static let userNameKey = "MyOllama.UserName"
    private static let assistantNameKey = "MyOllama.AssistantName"
    private static let memoryNotesKey = "MyOllama.MemoryNotes"
    private static let contextHistoryLimitKey = "MyOllama.ContextHistoryLimit"
    private static let voicevoxEnabledKey = "MyOllama.VoicevoxEnabled"
    private static let zundamonStyleIdKey = "MyOllama.ZundamonStyleId"
    private static let voiceSpeedScaleKey = "MyOllama.VoiceSpeedScale"
    private static let ragEnabledKey = "MyOllama.RAGEnabled"
    private static let webSearchEnabledKey = "MyOllama.WebSearchEnabled"
    private static let alwaysListeningKey = "MyOllama.AlwaysListening"

    @Published public var messages: [ChatMessage] = []
    @Published public var availableModels: [OllamaModelInfo] = []
    @Published public var selectedModel: String {
        didSet {
            if !selectedModel.isEmpty {
                UserDefaults.standard.set(selectedModel, forKey: Self.selectedModelKey)
            }
        }
    }
    @Published public var inputText: String = ""
    @Published public var systemPrompt: String {
        didSet {
            UserDefaults.standard.set(systemPrompt, forKey: Self.systemPromptKey)
        }
    }
    @Published public var selectedPersonaId: String {
        didSet {
            UserDefaults.standard.set(selectedPersonaId, forKey: Self.selectedPersonaIdKey)
        }
    }
    @Published public var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        }
    }
    @Published public var assistantName: String {
        didSet {
            UserDefaults.standard.set(assistantName, forKey: Self.assistantNameKey)
        }
    }
    @Published public var memoryNotes: String {
        didSet {
            UserDefaults.standard.set(memoryNotes, forKey: Self.memoryNotesKey)
        }
    }
    @Published public var contextHistoryLimit: Int {
        didSet {
            UserDefaults.standard.set(contextHistoryLimit, forKey: Self.contextHistoryLimitKey)
        }
    }
    @Published public var enableThinking: Bool {
        didSet {
            UserDefaults.standard.set(enableThinking, forKey: Self.enableThinkingKey)
        }
    }
    @Published public var isVoicevoxEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVoicevoxEnabled, forKey: Self.voicevoxEnabledKey)
            if !isVoicevoxEnabled {
                voicevox.stop()
            }
        }
    }
    @Published public var zundamonStyleId: Int {
        didSet {
            UserDefaults.standard.set(zundamonStyleId, forKey: Self.zundamonStyleIdKey)
        }
    }
    @Published public var voiceSpeedScale: Double {
        didSet {
            UserDefaults.standard.set(voiceSpeedScale, forKey: Self.voiceSpeedScaleKey)
        }
    }
    @Published public var isRAGEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRAGEnabled, forKey: Self.ragEnabledKey)
        }
    }
    @Published public var isWebSearchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWebSearchEnabled, forKey: Self.webSearchEnabledKey)
        }
    }
    @Published public var selectedTaskMode: TaskCommandMode = TaskCommandMode.defaultMode
    @Published public var activeCanvasDocument: CanvasDocument? = nil
    @Published public var isCanvasModeEnabled: Bool = false
    @Published public var attachedImages: [Data] = []
    @Published public var isGenerating: Bool = false
    @Published public var isLoadingModels: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var errorMessage: String? = nil

    public var currentPersona: PersonaPreset {
        PersonaPreset.presets.first(where: { $0.id == selectedPersonaId }) ?? PersonaPreset.presets[0]
    }

    public var isCurrentModelVisionSupported: Bool {
        guard let current = availableModels.first(where: { $0.name == selectedModel }) else {
            return false
        }
        return current.isVisionSupported
    }

    public var availableVisionModels: [OllamaModelInfo] {
        availableModels.filter { $0.isVisionSupported }
    }

    // MARK: - Context Window Calculation
    public var maxContextWindowTokens: Int {
        let name = selectedModel.lowercased()
        if name.contains("32k") { return 32768 }
        if name.contains("128k") { return 131072 }
        if name.contains("qwen") { return 32768 }
        if name.contains("gemma") { return 8192 }
        if name.contains("llama3") { return 8192 }
        if name.contains("phi") { return 4096 }
        return 8192
    }

    public var totalContextCharacters: Int {
        let sys = buildIntegratedSystemPrompt().count
        let historyToKeep = max(2, contextHistoryLimit * 2)
        let hist = messages.suffix(historyToKeep).reduce(0) { $0 + $1.content.count }
        let input = inputText.count
        return sys + hist + input
    }

    public var estimatedCurrentTokens: Int {
        Int(Double(totalContextCharacters) * 1.3)
    }

    public var contextUsagePercent: Double {
        let maxTokens = Double(maxContextWindowTokens)
        guard maxTokens > 0 else { return 0 }
        let percent = (Double(estimatedCurrentTokens) / maxTokens) * 100.0
        return min(100.0, max(0.0, percent))
    }

    public let voicevox = VoicevoxService.shared
    public let speechRecognizer = SpeechRecognitionService.shared
    public let openNotebook = OpenNotebookService.shared
    public let webSearch = WebSearchService.shared
    private let service = OllamaService.shared
    private var currentGenerationTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.selectedModel = UserDefaults.standard.string(forKey: Self.selectedModelKey) ?? ""
        self.enableThinking = UserDefaults.standard.bool(forKey: Self.enableThinkingKey)
        self.selectedPersonaId = UserDefaults.standard.string(forKey: Self.selectedPersonaIdKey) ?? "zundamon"
        self.userName = UserDefaults.standard.string(forKey: Self.userNameKey) ?? ""
        self.assistantName = UserDefaults.standard.string(forKey: Self.assistantNameKey) ?? ""
        self.memoryNotes = UserDefaults.standard.string(forKey: Self.memoryNotesKey) ?? ""
        self.contextHistoryLimit = UserDefaults.standard.object(forKey: Self.contextHistoryLimitKey) as? Int ?? 10
        self.isVoicevoxEnabled = UserDefaults.standard.object(forKey: Self.voicevoxEnabledKey) as? Bool ?? true
        self.zundamonStyleId = UserDefaults.standard.object(forKey: Self.zundamonStyleIdKey) as? Int ?? 3
        self.voiceSpeedScale = UserDefaults.standard.object(forKey: Self.voiceSpeedScaleKey) as? Double ?? 1.15
        self.isRAGEnabled = UserDefaults.standard.object(forKey: Self.ragEnabledKey) as? Bool ?? true
        self.isWebSearchEnabled = UserDefaults.standard.object(forKey: Self.webSearchEnabledKey) as? Bool ?? true

        if let savedPrompt = UserDefaults.standard.string(forKey: Self.systemPromptKey) {
            self.systemPrompt = savedPrompt
        } else {
            let defaultZundamonPrompt = PersonaPreset.presets.first(where: { $0.id == "zundamon" })?.defaultPrompt ?? ""
            self.systemPrompt = defaultZundamonPrompt
            UserDefaults.standard.set(defaultZundamonPrompt, forKey: Self.systemPromptKey)
        }

        // 子サービスの変更をViewModel全体にリアルタイム通知
        voicevox.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        speechRecognizer.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        Task {
            await loadModels()
            await voicevox.checkAvailability()
            await openNotebook.checkServerHealth()
        }
    }

    public func selectPersona(_ preset: PersonaPreset) {
        self.selectedPersonaId = preset.id
        if preset.id != "custom" {
            self.systemPrompt = preset.defaultPrompt
        }
        if let recVoice = preset.recommendedVoiceStyleId {
            self.zundamonStyleId = recVoice
        }
        if preset.id == "zundamon" && assistantName.isEmpty {
            self.assistantName = "ずんだもん"
        }
    }

    public func loadModels() async {
        isLoadingModels = true
        errorMessage = nil

        do {
            let models = try await service.fetchModels()
            self.availableModels = models
            self.isConnected = true
            self.isLoadingModels = false

            if !models.isEmpty {
                let savedModel = UserDefaults.standard.string(forKey: Self.selectedModelKey) ?? selectedModel
                if !savedModel.isEmpty, models.contains(where: { $0.name == savedModel }) {
                    selectedModel = savedModel
                } else if !selectedModel.isEmpty, models.contains(where: { $0.name == selectedModel }) {
                    // keep current
                } else {
                    if let preferred = models.first(where: { $0.isVisionSupported || $0.name.contains("qwen") || $0.name.contains("gemma") }) {
                        selectedModel = preferred.name
                    } else {
                        selectedModel = models[0].name
                    }
                }
            } else {
                self.errorMessage = "利用可能なモデルがありません。`ollama pull <model>` を実行してください。"
            }
        } catch let err as OllamaError {
            self.isConnected = false
            self.isLoadingModels = false
            self.errorMessage = err.localizedDescription
        } catch {
            self.isConnected = false
            self.isLoadingModels = false
            self.errorMessage = "接続エラー: \(error.localizedDescription)"
        }
    }

    public func attachImages(from urls: [URL]) {
        for url in urls {
            if let image = NSImage(contentsOf: url) {
                if let processedData = image.resizedData() {
                    attachedImages.append(processedData)
                } else if let rawData = try? Data(contentsOf: url) {
                    attachedImages.append(rawData)
                }
            }
        }
    }

    public func attachImage(data: Data) {
        if let image = NSImage(data: data),
           let processedData = image.resizedData() {
            attachedImages.append(processedData)
        } else {
            attachedImages.append(data)
        }
    }

    public func attachImages(_ dataList: [Data]) {
        for data in dataList {
            attachImage(data: data)
        }
    }

    public func removeAttachedImage(at index: Int) {
        guard attachedImages.indices.contains(index) else { return }
        attachedImages.remove(at: index)
    }

    public func clearAttachedImages() {
        attachedImages.removeAll()
    }

    public func speakMessage(_ text: String) {
        voicevox.speak(text: text, speakerId: zundamonStyleId, speedScale: voiceSpeedScale)
    }

    public func stopSpeaking() {
        voicevox.stop()
    }

    public func toggleSpeechRecognition() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            speechRecognizer.toggleRecording(
                onUpdate: { [weak self] recognized in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.inputText = recognized
                    }
                },
                onAutoSendTrigger: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self = self, !self.isGenerating else { return }
                        if !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.sendMessage()
                        }
                    }
                }
            )
        }
    }

    public func toggleAlwaysListening() {
        speechRecognizer.toggleAlwaysListening(
            onUpdate: { [weak self] recognized in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.inputText = recognized
                }
            },
            onAutoSendTrigger: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isGenerating else { return }
                    if !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.sendMessage()
                    }
                }
            }
        )
    }

    /// ワンクリックでリアルタイム音声通話（常時リスニング＋3Dずんだもん＋VOICEVOX）を全自動起動/停止
    public func toggleRealtimeVoiceCall() {
        if speechRecognizer.isAlwaysListening {
            speechRecognizer.stopRecording()
            voicevox.stop()
        } else {
            self.isVoicevoxEnabled = true
            toggleAlwaysListening()
            FloatingMascotController.shared.show(viewModel: self)
        }
    }

    /// Obsidianを起動して真っ白な新規ページを開き、ずんだもんフローティング召喚＆音声壁打ち通話を即座に開始！
    public func openBlankObsidianNoteAndStartCall() {
        if let target = ObsidianSyncService.shared.createAndOpenBlankNoteInObsidian() {
            self.selectedTaskMode = TaskCommandMode.allModes.first(where: { $0.id == "brainstorm" }) ?? selectedTaskMode
            self.isVoicevoxEnabled = true
            if !speechRecognizer.isAlwaysListening {
                toggleAlwaysListening()
            }
            FloatingMascotController.shared.show(viewModel: self)

            // メインウィンドウを最小化し、Obsidian画面全体を見渡せるようにする
            for window in NSApp.windows where !(window is NSPanel) {
                window.miniaturize(nil)
            }

            let reply = "Obsidianで真っ白な新規ノート「\(target.title).md」を開いたのだ！どんなアイデアを書くか、一緒に壁打ちするのだ！🌱✨"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if voicevox.isAvailable {
                speakMessage(reply)
            }
        }
    }

    public func buildIntegratedSystemPrompt(ragContext: String? = nil, webContext: String? = nil) -> String {
        var sections: [String] = []

        // 0. プロフェッショナル・タスクモード特化プロンプト（ブレスト・企画・論文・レビュー・コード等）
        let taskModifier = selectedTaskMode.promptModifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !taskModifier.isEmpty {
            sections.append(taskModifier)
        }

        // 0.1 音声対話モード時のコンパクト制約（通常モードまたは音声ON時）
        let isAudioMode = isVoicevoxEnabled || speechRecognizer.isRecording || speechRecognizer.isAlwaysListening
        if isAudioMode && selectedTaskMode.id == "normal" {
            sections.append("""
            【音声通話・リアルタイム会話モード制約】
            現在はユーザーと音声でリアルタイムに対話しています。
            ・回答は極めて短く、簡潔に、1〜3文（50〜100文字程度）で要点のみを返答してください。
            ・箇条書き、長いコードブロック、長文の解説、余計な前置きやまとめは絶対に避けてください。
            ・テンポの良い会話のキャッチボールができるよう、フレンドリーかつ端的に答えてください。
            """)
        }

        // 0.2 Obsidian リアルタイム共同執筆・Canvas壁打ちノート連携コンテキスト
        if let obsContent = ObsidianSyncService.shared.activeNoteContent,
           let obsTitle = ObsidianSyncService.shared.activeNoteTitle,
           ObsidianSyncService.shared.isSyncingWithObsidian {
            sections.append("""
            【🎨 Obsidian リアルタイム共同執筆・Canvas壁打ちモード】
            ユーザーは今、デスクトップ上のObsidianアプリで以下のMarkdownノートを見ながらあなたと音声で対話しています。
            ノート名: 「\(obsTitle).md」
            ---
            【現在のノート本文】:
            \(obsContent)
            ---
            【超重要: Canvasとしての直接ノート編集・追記ルール】
            ユーザーが「〜を書いて」「追記して」「直して」「まとめてノートに入れて」「構成を考えて」「〜のアイデアを追加して」など、ノートの更新を求めた場合：
            口頭で長々と説明するのではなく、Obsidianの画面上でノートを直接更新するため、以下のタグを使ってください：

            ・末尾に新しいアイデアや章を追記する場合:
            <<<CANVAS_APPEND>>>
            ### 💡 [タイトルや見出し]
            ・[追記内容...]
            <<<END_CANVAS_APPEND>>>

            ・ノート全体を整理・推敲・リライトする場合:
            <<<CANVAS_REPLACE>>>
            # \(obsTitle)
            ...全体の更新後のMarkdown...
            <<<END_CANVAS_REPLACE>>>

            ※タグの外側には、ずんだもん口調（〜なのだ）で短く「ノートに追記しておいたのだ！」「ノートの構成を整理したのだ！」と1文だけ発話してください。
            ※ただの質問やディスカッションの場合は、タグを使わずに通常通り短く口頭で答えてください。
            """)
        }

        // 1. システムプロンプト本体
        let trimmedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystemPrompt.isEmpty {
            sections.append(trimmedSystemPrompt)
        }

        // 2. ロール・名前設定
        var roleInfo: [String] = []
        let trimmedUser = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUser.isEmpty {
            roleInfo.append("対話相手（ユーザー）の呼び名: 「\(trimmedUser)」")
        }
        let trimmedAssistant = assistantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAssistant.isEmpty {
            roleInfo.append("あなた（AI）の名前・役割: 「\(trimmedAssistant)」")
        }
        if !roleInfo.isEmpty {
            sections.append("【役割・名前情報】\n" + roleInfo.joined(separator: "\n"))
        }

        // 3. 長期メモリ・記憶ノート
        let trimmedMemory = memoryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMemory.isEmpty {
            sections.append("【長期記憶・事前情報】\n以下はユーザーに関する永続的な記憶や前提条件です。会話の中で自然に考慮してください:\n\(trimmedMemory)")
        }

        // 4. Webリアルタイム検索・天気情報
        if let web = webContext, !web.isEmpty {
            sections.append("【Webリアルタイム情報（天気予報・最新検索結果）】\n以下はインターネットからリアルタイムに取得された最新データです。質問に正確に回答するために最優先で活用してください:\n\(web)")
        }

        // 5. RAG ナレッジ（検索結果）
        if let rag = ragContext, !rag.isEmpty {
            sections.append("【参考ナレッジ（Open Notebook / Obsidian RAG検索結果）】\n以下はユーザーの知識ベース（Obsidian Vault / ノートブック）から検索された関連情報です。回答を作成する際の参考にしてください:\n\(rag)")
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Canvas Helper Methods
    public func openCanvasWithObsidianNote(_ note: ObsidianNoteItem) {
        if let text = openNotebook.readObsidianNoteContent(at: note.url) {
            self.activeCanvasDocument = CanvasDocument(
                title: note.title,
                content: text,
                fileURL: note.url,
                isModified: false
            )
            self.isCanvasModeEnabled = true
        }
    }

    public func createNewCanvasDocument(title: String = "新規アイデア壁打ち", content: String = "# 新規アイデア壁打ち\n\n・テーマ:\n・背景:\n・アイデア・検討事項:\n") {
        self.activeCanvasDocument = CanvasDocument(
            title: title,
            content: content,
            fileURL: nil,
            isModified: true
        )
        self.isCanvasModeEnabled = true
    }

    public func saveActiveCanvasDocument() -> Bool {
        guard var doc = activeCanvasDocument else { return false }

        let targetURL: URL
        if let existing = doc.fileURL {
            targetURL = existing
        } else {
            let dir = ObsidianChatExportService.shared.getMyOllamaVaultDirectory()
            let safeTitle = doc.title.replacingOccurrences(of: "/", with: "-")
            targetURL = dir.appendingPathComponent("\(safeTitle).md")
            doc.fileURL = targetURL
        }

        do {
            try doc.content.write(to: targetURL, atomically: true, encoding: .utf8)
            doc.isModified = false
            self.activeCanvasDocument = doc
            openNotebook.loadObsidianNotes()
            return true
        } catch {
            return false
        }
    }

    /// メッセージ送信
    public func sendMessage() {
        speechRecognizer.cancelAutoSendTimer()
        voicevox.stop()

        var text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || !attachedImages.isEmpty), !isGenerating, !selectedModel.isEmpty else { return }

        // スラッシュコマンド（/plan, /brainstorm 等）の動的検知とモード切り替え
        for mode in TaskCommandMode.allModes where mode.id != "normal" {
            if text.hasPrefix(mode.slashCommand) {
                self.selectedTaskMode = mode
                if mode.autoEnableThinking {
                    self.enableThinking = true
                }
                text = text.dropFirst(mode.slashCommand.count).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if text.isEmpty && !attachedImages.isEmpty {
            text = "この画像について説明してください。"
        }

        let currentAttachedImages = attachedImages
        attachedImages.removeAll()

        let userMsg = ChatMessage(
            role: .user,
            content: text,
            imageDataList: currentAttachedImages
        )
        messages.append(userMsg)
        inputText = ""
        speechRecognizer.resetRecognitionSession()
        errorMessage = nil

        if let action = VoiceCommandEngine.detectCommand(from: text) {
            handleVoiceCommand(action: action)
            return
        }

        let assistantMsgId = UUID()
        let assistantMsg = ChatMessage(
            id: assistantMsgId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMsg)
        isGenerating = true

        let queryText = text
        let thinkingFlag = enableThinking
        let ragEnabled = isRAGEnabled
        let webSearchEnabled = isWebSearchEnabled || webSearch.isWeatherQuery(queryText)
        let voicevoxEnabled = isVoicevoxEnabled && voicevox.isAvailable
        let currentSpeakerId = zundamonStyleId
        let currentSpeed = voiceSpeedScale

        // 🌟 ゼロクリック自動化: ボタンを押していなくても、Obsidianノートが利用可能なら自動同期
        let queryLower = queryText.lowercased()
        if ObsidianSyncService.shared.activeNoteURL == nil ||
           queryLower.contains("ノート") || queryLower.contains("obsidian") ||
           queryLower.contains("追記") || queryLower.contains("書いて") ||
           queryLower.contains("壁打ち") || queryLower.contains("アイデア") {
            _ = ObsidianSyncService.shared.syncLatestObsidianNote()
        }

        currentGenerationTask = Task {
            // 1. Web / 天気 リアルタイム検索
            var webContextString: String? = nil
            var webSearchResults: [WebSearchResultItem] = []
            if webSearchEnabled {
                webSearchResults = await self.webSearch.searchWeb(query: queryText)
                if !webSearchResults.isEmpty {
                    let formattedWeb = webSearchResults.map { hit -> String in
                        "■ \(hit.title)\n\(hit.snippet)"
                    }
                    webContextString = formattedWeb.joined(separator: "\n\n")

                    if let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[index].referencedWebSources = webSearchResults
                    }
                }
            }

            // 2. RAG 検索
            var ragContextString: String? = nil
            var ragSearchResults: [OpenNotebookSearchResult] = []
            if ragEnabled {
                ragSearchResults = await self.openNotebook.searchRAG(query: queryText, limit: 3)
                if !ragSearchResults.isEmpty {
                    let formattedHits = ragSearchResults.map { hit -> String in
                        "■ タイトル: \(hit.title)\n本文抜粋: \(hit.content.prefix(500))"
                    }
                    ragContextString = formattedHits.joined(separator: "\n\n")

                    if let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[index].referencedRagSources = ragSearchResults
                    }
                }
            }

            // 3. コンテキストメッセージの組み立て
            var contextMessages: [ChatMessage] = []

            let fullSystemPrompt = self.buildIntegratedSystemPrompt(
                ragContext: ragContextString,
                webContext: webContextString
            )
            if !fullSystemPrompt.isEmpty {
                contextMessages.append(ChatMessage(role: .system, content: fullSystemPrompt))
            }

            let historyToKeep = max(2, self.contextHistoryLimit * 2)
            let previousMessages = Array(self.messages.dropLast())
            let slicedHistory = Array(previousMessages.suffix(historyToKeep))
            contextMessages.append(contentsOf: slicedHistory)

            var currentSpeechBuffer = ""
            var isInThinkTag = false

            do {
                let stream = await self.service.sendChatStream(
                    model: self.selectedModel,
                    messages: contextMessages,
                    think: thinkingFlag
                )

                for try await token in stream {
                    if Task.isCancelled { break }
                    if let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[index].content += token
                    }

                    if voicevoxEnabled {
                        currentSpeechBuffer += token

                        if currentSpeechBuffer.contains("<think>") {
                            isInThinkTag = true
                        }
                        if currentSpeechBuffer.contains("</think>") {
                            isInThinkTag = false
                            if let endRange = currentSpeechBuffer.range(of: "</think>") {
                                currentSpeechBuffer = String(currentSpeechBuffer[endRange.upperBound...])
                            }
                        }

                        if !isInThinkTag {
                            let delimiters: [Character] = ["。", "！", "？", "!", "?", "\n"]
                            if let lastChar = token.last, delimiters.contains(lastChar) || currentSpeechBuffer.count >= 40 {
                                let chunkToSpeak = currentSpeechBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !chunkToSpeak.isEmpty {
                                    self.voicevox.enqueueChunk(
                                        text: chunkToSpeak,
                                        speakerId: currentSpeakerId,
                                        speedScale: currentSpeed
                                    )
                                    currentSpeechBuffer = ""
                                }
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "応答生成エラー: \(error.localizedDescription)"
                }
            }

            if voicevoxEnabled && !isInThinkTag && !currentSpeechBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.voicevox.enqueueChunk(
                    text: currentSpeechBuffer,
                    speakerId: currentSpeakerId,
                    speedScale: currentSpeed
                )
            }

            if let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                self.messages[index].isStreaming = false
                if self.messages[index].content.isEmpty && !Task.isCancelled {
                    self.messages[index].content = "(応答が得られませんでした)"
                } else {
                    // 🎨 Canvas Update: AI応答にノート更新タグがあればObsidianファイルを直接物理更新！
                    let (cleanedText, didUpdate, actionDesc) = ObsidianSyncService.shared.processAIResponseForCanvasUpdate(
                        aiResponse: self.messages[index].content,
                        userPrompt: queryText
                    )
                    self.messages[index].content = cleanedText
                    if didUpdate, let desc = actionDesc, voicevoxEnabled {
                        // 更新完了をずんだもんが音声で報告
                        self.voicevox.enqueueChunk(text: desc, speakerId: currentSpeakerId, speedScale: currentSpeed)
                    }
                }
            }
            self.isGenerating = false
            self.currentGenerationTask = nil
        }
    }

    private func handleVoiceCommand(action: VoiceAction) {
        switch action {
        case .resetChat:
            let reply = "チャット履歴をリセットしたのだ！新しい話題をどうぞなのだ！"
            self.messages.removeAll()
            let msg = ChatMessage(role: .assistant, content: reply)
            self.messages.append(msg)
            if isVoicevoxEnabled && voicevox.isAvailable {
                speakMessage(reply)
            }

        case .compressContext:
            if self.messages.isEmpty {
                let reply = "まだ要約する会話履歴がないのだ！"
                let msg = ChatMessage(role: .assistant, content: reply)
                self.messages.append(msg)
                if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }
                return
            }

            let extractingMsgId = UUID()
            self.messages.append(ChatMessage(id: extractingMsgId, role: .assistant, content: "これまでの会話から、あなたの性格・好み・重要事項を抽出して記憶に記録中なのだ...", isStreaming: true))
            self.isGenerating = true

            Task {
                if let updatedMemory = await MemoryExtractionService.shared.extractMemories(
                    from: self.messages.dropLast(),
                    currentMemory: self.memoryNotes,
                    model: self.selectedModel
                ) {
                    self.memoryNotes = updatedMemory
                }

                self.messages.removeAll()
                let reply = "あなたの性格や好み、これまでの重要事項を長期記憶（メモリー）にしっかりと保存したのだ！過去の履歴も整理してすっきりしたのだ！"
                let finalMsg = ChatMessage(role: .assistant, content: reply)
                self.messages.append(finalMsg)
                self.isGenerating = false

                if self.isVoicevoxEnabled && self.voicevox.isAvailable {
                    self.speakMessage(reply)
                }
            }

        case .stopSpeaking:
            voicevox.stop()

        case .enableThinking:
            enableThinking = true
            let reply = "思考モード（think）を有効にしたのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }

        case .disableThinking:
            enableThinking = false
            let reply = "思考モード（think）を無効にしたのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }

        case .enableRAG:
            isRAGEnabled = true
            let reply = "RAG（知識ベース検索）を有効にしたのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }

        case .disableRAG:
            isRAGEnabled = false
            let reply = "RAG（知識ベース検索）を無効にしたのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }

        case .saveToObsidian:
            if self.messages.isEmpty {
                let reply = "まだ保存する会話履歴がないのだ！"
                let msg = ChatMessage(role: .assistant, content: reply)
                self.messages.append(msg)
                if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }
                return
            }

            let savingMsgId = UUID()
            self.messages.append(ChatMessage(id: savingMsgId, role: .assistant, content: "会話のタイトルとまとめを作成してObsidianに保存中なのだ...", isStreaming: true))
            self.isGenerating = true

            Task {
                let (success, fileName, _) = await ObsidianChatExportService.shared.saveChatToObsidian(
                    messages: self.messages.dropLast(),
                    model: self.selectedModel,
                    personaName: self.currentPersona.name
                )
                self.isGenerating = false

                if let index = self.messages.firstIndex(where: { $0.id == savingMsgId }) {
                    self.messages.remove(at: index)
                }

                let reply: String
                if success, let name = fileName {
                    reply = "会話の要約とログを Obsidian の myollama フォルダに「\(name)」として保存したのだ！📚✨"
                } else {
                    reply = "Obsidian への保存に失敗してしまったのだ... パスを確認してほしいのだ。"
                }

                let finalMsg = ChatMessage(role: .assistant, content: reply)
                self.messages.append(finalMsg)

                if self.isVoicevoxEnabled && self.voicevox.isAvailable {
                    self.speakMessage(reply)
                }
            }

        case .runAgentPlan:
            let startMsg = "自律タスクの実行を開始するのだ！AI-tradingやume-lunchの処理を順次進めていくのだ！⚙️✨"
            self.messages.append(ChatMessage(role: .assistant, content: startMsg))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(startMsg) }

            Task {
                await AgentTaskPlanningService.shared.executeAllTasks { [weak self] update in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.errorMessage = update
                    }
                }
                let finishMsg = "すべてのエージェントタスクが完了したのだ！タスク画面やグラフ画面で結果を確認できるのだ！🌱✨"
                self.messages.append(ChatMessage(role: .assistant, content: finishMsg))
                if self.isVoicevoxEnabled && self.voicevox.isAvailable { self.speakMessage(finishMsg) }
            }

        case .syncObsidianLatest:
            if let target = ObsidianSyncService.shared.syncLatestObsidianNote() {
                self.selectedTaskMode = TaskCommandMode.allModes.first(where: { $0.id == "brainstorm" }) ?? selectedTaskMode
                let reply = "Obsidianで開いている最新ノート「\(target.title).md」を読み込んだのだ！このノートを見ながら何でも壁打ちしてほしいのだ！🌱✨"
                self.messages.append(ChatMessage(role: .assistant, content: reply))
                if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }
            } else {
                let reply = "Obsidianのノートが見つからなかったのだ。Obsidianフォルダの設定を確認してほしいのだ！"
                self.messages.append(ChatMessage(role: .assistant, content: reply))
                if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }
            }

        case .clearObsidianSync:
            ObsidianSyncService.shared.clearSync()
            let reply = "Obsidianノートとの壁打ち連携を解除したのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }

        case .switchMode(let mode):
            selectedTaskMode = mode
            if mode.autoEnableThinking {
                enableThinking = true
            }
            let reply = "【\(mode.name)】モードに切り替えたのだ！\(mode.description)なのだ！"
            self.messages.append(ChatMessage(role: .assistant, content: reply))
            if isVoicevoxEnabled && voicevox.isAvailable { speakMessage(reply) }
        }
    }

    /// 画面ボタン等から手動でObsidianに保存
    public func saveCurrentChatToObsidian() async -> (success: Bool, fileName: String?) {
        guard !messages.isEmpty else { return (false, nil) }
        let (success, fileName, _) = await ObsidianChatExportService.shared.saveChatToObsidian(
            messages: messages,
            model: selectedModel,
            personaName: currentPersona.name
        )
        return (success, fileName)
    }

    public func stopGenerating() {
        currentGenerationTask?.cancel()
        currentGenerationTask = nil
        isGenerating = false
        voicevox.stop()
        if let lastIndex = messages.indices.last, messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
            if messages[lastIndex].content.isEmpty {
                messages[lastIndex].content = "(中断されました)"
            }
        }
    }

    public func extractMemoryFromCurrentChat() async -> Bool {
        guard !messages.isEmpty else { return false }
        if let updated = await MemoryExtractionService.shared.extractMemories(
            from: messages,
            currentMemory: memoryNotes,
            model: selectedModel
        ) {
            self.memoryNotes = updated
            return true
        }
        return false
    }

    /// 選択された英文の直訳・意訳・文法解説・単語リスト解析をリクエスト
    public func requestEnglishAnalysis(text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // ウィンドウを前面に出す
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }

        let prompt = EnglishLearningService.shared.buildEnglishAnalysisPrompt(text: clean)
        self.inputText = prompt
        self.sendMessage()
    }

    public func clearChat() {
        stopGenerating()
        messages.removeAll()
        attachedImages.removeAll()
        errorMessage = nil
    }
}

// MARK: - NSImage Helper for Resizing & JPEG Compression
extension NSImage {
    func resizedData(maxDimension: CGFloat = 1200, compressionQuality: Double = 0.8) -> Data? {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        var width = CGFloat(bitmap.pixelsWide)
        var height = CGFloat(bitmap.pixelsHigh)
        if width <= 0 || height <= 0 {
            width = self.size.width
            height = self.size.height
        }

        let scale = min(1.0, maxDimension / max(width, height))
        let newWidth = width * scale
        let newHeight = height * scale

        let newImage = NSImage(size: NSSize(width: newWidth, height: newHeight))
        newImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight),
                  from: NSRect.zero,
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()

        guard let newTiff = newImage.tiffRepresentation,
              let newBitmap = NSBitmapImageRep(data: newTiff) else {
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        }
        return newBitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
