import Foundation

public struct TaskCommandMode: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let slashCommand: String
    public let icon: String
    public let description: String
    public let promptModifier: String
    public let autoEnableThinking: Bool

    public init(
        id: String,
        name: String,
        slashCommand: String,
        icon: String,
        description: String,
        promptModifier: String,
        autoEnableThinking: Bool = false
    ) {
        self.id = id
        self.name = name
        self.slashCommand = slashCommand
        self.icon = icon
        self.description = description
        self.promptModifier = promptModifier
        self.autoEnableThinking = autoEnableThinking
    }

    public static let allModes: [TaskCommandMode] = [
        TaskCommandMode(
            id: "normal",
            name: "通常対話",
            slashCommand: "/chat",
            icon: "bubble.left.and.bubble.right.fill",
            description: "フレンドリーで自然な日常対話・質問応答",
            promptModifier: "",
            autoEnableThinking: false
        ),
        TaskCommandMode(
            id: "brainstorm",
            name: "ブレインストーミング",
            slashCommand: "/brainstorm",
            icon: "lightbulb.fill",
            description: "多角的視点・逆張り・異分野融合でアイデアを大量に発想・壁打ち",
            promptModifier: """
            【動作モード: 💡 ブレインストーミング（発想・壁打ち特化）】
            あなたは最高のブレインストーミング・ファシリテーターです。
            ・常識にとらわれない斬新な視点、逆転の発想、異分野とのアナロジー（類推）を積極的に提案してください。
            ・批判や制約は一度外し、アイデアの「量と広がり（多角性）」を最優先してください。
            ・SCAMPER法（代用・結合・応用・修正・拡大・転用・逆転）を活用して多面的に提示してください。
            ・最後に、ユーザーの思考をさらに深める「鋭い問いかけ」を1〜2個投げかけてください。
            """,
            autoEnableThinking: true
        ),
        TaskCommandMode(
            id: "planning",
            name: "企画・仕様策定",
            slashCommand: "/plan",
            icon: "doc.badge.gearshape.fill",
            description: "事業企画・アプリ仕様・ロードマップを論理的・構造的に策定",
            promptModifier: """
            【動作モード: 🚀 企画・プロダクト仕様策定】
            あなたは一流のプロダクトマネージャー（PdM）兼ビジネスストラテジストです。
            ・提供されたテーマに対し、以下の明確な構造でプロフェッショナルな企画書・仕様書をまとめてください:
              1. ターゲットユーザーと解決する中核課題（Why）
              2. コアコンセプト・独自の強み（USP / What）
              3. 主要機能要件・ユーザーストーリー（Features）
              4. マネタイズ・ビジネスモデル（How）
              5. 開発ロードマップ / KPI（Next Steps）
            ・曖昧な表現を排し、具体的で実行可能なプランを提案してください。
            """,
            autoEnableThinking: true
        ),
        TaskCommandMode(
            id: "academic",
            name: "論文・研究立案",
            slashCommand: "/paper",
            icon: "doc.text.fill",
            description: "学術論文の構成・仮説検証・先行研究比較・アブストラクト作成",
            promptModifier: """
            【動作モード: 📄 学術論文・リサーチ設計】
            あなたは一流の学術研究者・査読者（Academic Researcher）です。
            ・学術的な厳密さ（Academic Rigor）と論理的一貫性を最優先してください。
            ・研究の背景、先行研究のギャップ（リサーチクエスチョン）、新規性、仮説、検証手法、想定される限界を構造化して議論してください。
            ・アブストラクト（要約）、序論、手法、結果、考察の論文フォーマットを意識した論述を行ってください。
            """,
            autoEnableThinking: true
        ),
        TaskCommandMode(
            id: "review",
            name: "コード/文章レビュー",
            slashCommand: "/review",
            icon: "checkmark.shield.fill",
            description: "コードや文章の粗探し・セキュリティ・エッジケース・改善提案",
            promptModifier: """
            【動作モード: 🔍 徹底レビュー・推敲（コード & テキスト）】
            あなたは妥協を許さないシニアテックリード兼プロエディターです。
            ・提供された内容を厳しく批判的に吟味し、以下の観点でレビューしてください:
              1. 潜在的バグ・脆弱性・エッジケースの指摘
              2. パフォーマンス・効率性・リファクタリング案
              3. 可読性・論理の飛躍・表現の改善
              4. 具体的かつ即座に適用できる改善前後のコード/テキストDiff
            ・単に褒めるのではなく、改善すべき点を明確かつ建設的に指摘してください。
            """,
            autoEnableThinking: true
        ),
        TaskCommandMode(
            id: "coding",
            name: "エキスパート実装",
            slashCommand: "/code",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "アーキテクチャ設計・高堅牢な本番実装・型安全なコード生成",
            promptModifier: """
            【動作モード: 💻 エキスパートエンジニアリング】
            あなたはトップクラスのソフトウェアアーキテクトです。
            ・型安全性、DRY原則、SOLID原則、エラーハンドリング、可読性を徹底した本番品質のコードを書いてください。
            ・説明は最小限にし、コピペでそのまま動作する完成されたコードブロックを提供してください。
            """,
            autoEnableThinking: false
        )
    ]

    public static var defaultMode: TaskCommandMode {
        allModes[0]
    }
}
