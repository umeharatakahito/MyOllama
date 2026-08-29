import SwiftUI

public struct PromptTemplate: Identifiable {
    public let id = UUID()
    public let title: String
    public let framework: String // "RCTF", "7R", "PREP", etc.
    public let icon: String
    public let color: Color
    public let description: String
    public let templateText: String
    public let recommendedModeId: String
}

public struct PromptEngineeringDashboardView: View {
    @ObservedObject var viewModel: ChatViewModel
    public var onOpenMemory: (() -> Void)?
    public var onOpenRAG: (() -> Void)?

    @State private var selectedFramework: String = "ALL"

    public init(
        viewModel: ChatViewModel,
        onOpenMemory: (() -> Void)? = nil,
        onOpenRAG: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onOpenMemory = onOpenMemory
        self.onOpenRAG = onOpenRAG
    }

    private let promptTemplates: [PromptTemplate] = [
        PromptTemplate(
            title: "🎨 MD Canvas ノート壁打ち",
            framework: "Canvas",
            icon: "square.split.2x1.fill",
            color: .indigo,
            description: "左側のMarkdownノートを見ながら、ずんだもんとリアルタイムにアイデアや構成を壁打ち",
            templateText: "現在Canvasで開いているMarkdownノートの内容について、改善点や新しいアイデアを一緒にブレインストーミングしてください！",
            recommendedModeId: "brainstorm"
        ),
        PromptTemplate(
            title: "新規事業・プロダクト企画書",
            framework: "RCTF",
            icon: "doc.badge.gearshape.fill",
            color: .blue,
            description: "ターゲット課題・USP・主要機能要件・ビジネスモデルを構造化策定",
            templateText: """
            【Role (役割)】一流のプロダクトマネージャー（PdM）兼ビジネスストラテジスト
            【Context (前提・背景)】
            ・対象領域: [例: 個人開発・AIを活用した生産性向上ツール]
            ・ターゲット層: [例: 忙しいフリーランスエンジニア]
            【Task (目的・タスク)】
            上記のターゲットに向けた新しいプロダクトの企画書を作成してください。
            【Format (出力形式)】
            1. 解決する中核課題 (Why)
            2. コアコンセプト・独自の強み (What / USP)
            3. 主要機能要件 3選 (Features)
            4. マネタイズ・ビジネスモデル (How)
            5. 次のアクション・検証ロードマップ
            """,
            recommendedModeId: "planning"
        ),
        PromptTemplate(
            title: "多角的ブレインストーミング・壁打ち",
            framework: "7R",
            icon: "lightbulb.fill",
            color: .orange,
            description: "SCAMPER法・逆張り思考・異分野融合でアイデアを大量に発想",
            templateText: """
            【1. Role (役割)】常識にとらわれないアイデア発想のエキスパートファシリテーター
            【2. Request (依頼)】以下のテーマに関する斬新なアイデアを多角的に10個提案してください。
            【3. Reason (目的)】[例: 競合と差別化されたユニークなサービスを立ち上げたい]
            【4. Resource (前提テーマ)】[例: 音声対話を活用した新しいデスクトップ体験]
            【5. Requirement (要件)】王道案だけでなく、逆張り思考や異分野との掛け合わせ案を必ず含めること。
            【6. Result (期待成果物)】各アイデアに「タイトル」「概要」「なぜ面白いか」を明記。
            【7. Rule (ルール)】最後に私の思考をさらに深める鋭い問いかけを2つ投げかけてください。
            """,
            recommendedModeId: "brainstorm"
        ),
        PromptTemplate(
            title: "徹底コードレビュー & 脆弱性診断",
            framework: "RCTF",
            icon: "checkmark.shield.fill",
            color: .green,
            description: "潜在バグ・セキュリティ・エッジケース・可読性の批判的吟味と改善Diff",
            templateText: """
            【Role (役割)】妥協を許さないシニアソフトウェアアーキテクト
            【Context (コードのコンテキスト)】
            ・使用言語/FW: [例: Swift / SwiftUI / Concurrency]
            ・対象コード:
            ```
            [ここにコードを貼り付け]
            ```
            【Task (タスク)】
            提供されたコードを厳しくレビューし、改善案を提示してください。
            【Format (出力形式)】
            1. 致命的な不具合・競合状態・メモリリークの指摘
            2. 可読性・保守性・DRY原則の観点からの改善点
            3. リファクタリング前後の具体的なコードDiff
            """,
            recommendedModeId: "review"
        ),
        PromptTemplate(
            title: "学術論文構成・リサーチ設計",
            framework: "7R",
            icon: "doc.text.fill",
            color: .purple,
            description: "研究背景・先行研究ギャップ・仮説・新規性・アブストラクト作成",
            templateText: """
            【1. Role (役割)】トップカンファレンス論文の査読者兼アカデミック研究者
            【2. Request (依頼)】以下の研究テーマに関する論文構成案とアブストラクトを作成してください。
            【3. Resource (研究テーマ)】[例: ローカルLLMと音声対話を統合したデスクトップエージェントの応答遅延最適化]
            【4. Requirement (要件)】新規性（Novelty）と先行研究との差分（Research Gap）を明確に論じること。
            【5. Format (出力形式)】
            ・Abstract (背景, 課題, 提案手法, 想定結果)
            ・Introduction (研究の動機と貢献)
            ・Proposed Method (手法の論理構成)
            ・Evaluation (評価指標と実験設計)
            """,
            recommendedModeId: "academic"
        ),
        PromptTemplate(
            title: "結論ファースト・PREP解説",
            framework: "PREP",
            icon: "text.alignleft",
            color: .indigo,
            description: "Point (結論) -> Reason (理由) -> Example (具体例) -> Point (まとめ)",
            templateText: """
            【テーマ】: [例: なぜローカルLLMを導入するべきなのか？]
            上記のテーマについて、PREP法（結論 → 理由 → 具体例 → 結論）を用いて、説得力のある論述を行ってください。
            読者が一目で理解できるよう、重要なキーワードは太字にし、各ステップを明確に見出し分けしてください。
            """,
            recommendedModeId: "normal"
        ),
        PromptTemplate(
            title: "第一原理思考による根本課題解決",
            framework: "思考",
            icon: "brain.head.profile.fill",
            color: .pink,
            description: "前提を疑い、基本的事実に分解してゼロベースで解決策を導出",
            templateText: """
            【解決したい課題】: [例: 音声対話のレスポンスが遅く、会話のテンポが悪くなってしまう]
            上記の課題を「第一原理（First Principles）」に基づいて根本原因に分解してください。
            1. 一般的な思い込みや既成概念の特定
            2. 動かしようのない基本的構成要素への分解
            3. ゼロベースで再構築した革新的な解決アプローチ
            """,
            recommendedModeId: "brainstorm"
        )
    ]

    private let quickFormatTags = [
        "📌 箇条書きで要点を簡潔に",
        "📊 Markdown表で比較して",
        "💡 ステップバイステップで解説",
        "🎯 結論ファーストで",
        "💻 コードブロックのみ出力",
        "🗣️ ずんだもん口調（〜なのだ）で回答"
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 🌟 BIG HERO: リアルタイム音声通話大型起動バナー
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.toggleRealtimeVoiceCall()
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(viewModel.speechRecognizer.isAlwaysListening ? Color.red : Color.green)
                                .frame(width: 44, height: 44)
                            Image(systemName: viewModel.speechRecognizer.isAlwaysListening ? "waveform" : "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(viewModel.speechRecognizer.isAlwaysListening ? "🎙️ リアルタイム音声通話中..." : "🎙️ ずんだもんとリアルタイム音声対話を始める")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)

                                Text(viewModel.speechRecognizer.isAlwaysListening ? "通話中（クリックで停止）" : "ワンクリック起動")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(viewModel.speechRecognizer.isAlwaysListening ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                    .foregroundColor(viewModel.speechRecognizer.isAlwaysListening ? .red : .green)
                                    .clipShape(Capsule())
                            }

                            Text(viewModel.speechRecognizer.isAlwaysListening ? "マイクに向かって話しかけると自動で回答します。クリックで通話を終了できます。" : "常時ハンズフリー認識 ＋ 3Dずんだもんマスコット召喚 ＋ 音声読み上げを一発で起動します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: viewModel.speechRecognizer.isAlwaysListening ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.speechRecognizer.isAlwaysListening ? .red : .green)
                    }
                    .padding(14)
                    .background(
                        viewModel.speechRecognizer.isAlwaysListening
                        ? LinearGradient(colors: [Color.purple.opacity(0.25), Color.red.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.green.opacity(0.2), Color.purple.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(viewModel.speechRecognizer.isAlwaysListening ? Color.purple : Color.green.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: viewModel.speechRecognizer.isAlwaysListening ? Color.purple.opacity(0.2) : Color.green.opacity(0.15), radius: 4)
                }
                .buttonStyle(.plain)

                // 📝 Obsidian 新規白紙ノートを開いて壁打ちスタート バナー
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.openBlankObsidianNoteAndStartCall()
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.cyan)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("📝 Obsidianを起動して真っ白なページで壁打ち")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Obsidian連携")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.2))
                                    .foregroundColor(.cyan)
                                    .clipShape(Capsule())
                            }

                            Text("Obsidianに新規白紙ノートを作成・起動し、フローティングずんだもんと即座に音声壁打ちを開始します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }
                    .padding(14)
                    .background(
                        LinearGradient(colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Color.cyan.opacity(0.15), radius: 4)
                }
                .buttonStyle(.plain)

                // Top Header Banner
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("プロンプトエンジニアリング Studio")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("7R / RCTF 構造化ダッシュボード")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.18))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                        Text("役割(R)・文脈(C)・タスク(T)・形式(F) をマウスで直感的に組み立て、AIの能力を最大限に引き出します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // 1. RCTF / 7R リアルタイム設定ステータス（マウスで即座に変更可能）
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚙️ 現在のプロンプト構成パラメーター (RCTF)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        // R: Role & Persona
                        statusCard(
                            letter: "R",
                            title: "Role (役割・ペルソナ)",
                            value: viewModel.currentPersona.name,
                            icon: viewModel.currentPersona.systemImage,
                            color: .purple
                        ) {
                            Menu {
                                ForEach(PersonaPreset.presets) { preset in
                                    Button(action: {
                                        viewModel.selectPersona(preset)
                                    }) {
                                        Label(preset.name, systemImage: preset.systemImage)
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text("変更")
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .menuStyle(.borderlessButton)
                        }

                        // C: Context & Memory (クリックでメモリ管理画面オープン)
                        statusCard(
                            letter: "C",
                            title: "Context (記憶・前提背景)",
                            value: viewModel.memoryNotes.isEmpty ? "長期記憶なし (クリックで追加)" : "記憶: \(viewModel.memoryNotes.split(separator: "\n").count)件ロード中",
                            icon: "brain.head.profile.fill",
                            color: .indigo
                        ) {
                            Button(action: {
                                onOpenMemory?()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9))
                                    Text("記憶を管理")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.indigo.opacity(0.15))
                                .foregroundColor(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // T: Task Mode
                        statusCard(
                            letter: "T",
                            title: "Task (動作モード・目的)",
                            value: viewModel.selectedTaskMode.name,
                            icon: viewModel.selectedTaskMode.icon,
                            color: .blue
                        ) {
                            Menu {
                                ForEach(TaskCommandMode.allModes) { mode in
                                    Button(action: {
                                        viewModel.selectedTaskMode = mode
                                        if mode.autoEnableThinking {
                                            viewModel.enableThinking = true
                                        }
                                    }) {
                                        Label(mode.name, systemImage: mode.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text("切替")
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .menuStyle(.borderlessButton)
                        }

                        // F / Resource: RAG & Web (クリックでトグル & ノート管理オープン)
                        statusCard(
                            letter: "F",
                            title: "Resource (知識・検索)",
                            value: "RAG: \(viewModel.isRAGEnabled ? "ON" : "OFF") / Web: \(viewModel.isWebSearchEnabled ? "ON" : "OFF")",
                            icon: "globe.asia.australia.fill",
                            color: .cyan
                        ) {
                            HStack(spacing: 4) {
                                Button(action: {
                                    withAnimation {
                                        viewModel.isWebSearchEnabled.toggle()
                                    }
                                }) {
                                    Text("Web: \(viewModel.isWebSearchEnabled ? "ON" : "OFF")")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(viewModel.isWebSearchEnabled ? Color.blue.opacity(0.2) : Color.primary.opacity(0.06))
                                        .foregroundColor(viewModel.isWebSearchEnabled ? .blue : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    withAnimation {
                                        viewModel.isRAGEnabled.toggle()
                                    }
                                }) {
                                    Text("RAG: \(viewModel.isRAGEnabled ? "ON" : "OFF")")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(viewModel.isRAGEnabled ? Color.cyan.opacity(0.2) : Color.primary.opacity(0.06))
                                        .foregroundColor(viewModel.isRAGEnabled ? .cyan : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                if let onRAG = onOpenRAG {
                                    Button(action: onRAG) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 10))
                                            .padding(4)
                                            .background(Color.cyan.opacity(0.12))
                                            .foregroundColor(.cyan)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Obsidian RAGノート一覧を開く")
                                }
                            }
                        }
                    }
                }

                // 2. 出力形式クイックタグ (Format & Tone Rules)
                VStack(alignment: .leading, spacing: 8) {
                    Text("🏷️ 出力形式・トーンのクイック付加 (クリックで入力欄に挿入)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickFormatTags, id: \.self) { tag in
                                Button(action: {
                                    if viewModel.inputText.isEmpty {
                                        viewModel.inputText = tag + "\n"
                                    } else {
                                        viewModel.inputText += "\n" + tag
                                    }
                                }) {
                                    Text(tag)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .foregroundColor(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider()

                // 3. 7R / RCTF テンプレート集（ワンクリックでプロンプト生成）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("✨ 構造化プロンプト・テンプレート（7R / RCTF 準拠）")
                                .font(.system(size: 13, weight: .bold))
                            Text("クリックすると、フレームワークに沿った高品質なテンプレートが入力欄にセットされます")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(promptTemplates) { tpl in
                            Button(action: {
                                if tpl.framework == "Canvas" {
                                    viewModel.isCanvasModeEnabled = true
                                    if viewModel.activeCanvasDocument == nil {
                                        viewModel.createNewCanvasDocument()
                                    }
                                }
                                viewModel.inputText = tpl.templateText
                                if let mode = TaskCommandMode.allModes.first(where: { $0.id == tpl.recommendedModeId }) {
                                    viewModel.selectedTaskMode = mode
                                    if mode.autoEnableThinking {
                                        viewModel.enableThinking = true
                                    }
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tpl.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(tpl.color)
                                        Text(tpl.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(tpl.framework)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(tpl.color.opacity(0.15))
                                            .foregroundColor(tpl.color)
                                            .clipShape(Capsule())
                                    }

                                    Text(tpl.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    HStack {
                                        Spacer()
                                        HStack(spacing: 3) {
                                            Text("テンプレートを使う")
                                            Image(systemName: "arrow.down.right.circle.fill")
                                        }
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(tpl.color)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(tpl.color.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private func statusCard<Actions: View>(
        letter: String,
        title: String,
        value: String,
        icon: String,
        color: Color,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(letter)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    actions()
                }

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
