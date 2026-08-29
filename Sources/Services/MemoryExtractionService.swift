import Foundation

public struct UserMemoryCategory: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public var items: [String]

    public init(title: String, icon: String, items: [String]) {
        self.title = title
        self.icon = icon
        self.items = items
    }
}

public final class MemoryExtractionService: @unchecked Sendable {
    public static let shared = MemoryExtractionService()

    private init() {}

    /// 会話履歴からユーザーの特徴・重要事項・性格・好みを抽出して構造化要約を生成
    public func extractMemories(from messages: [ChatMessage], currentMemory: String, model: String) async -> String? {
        guard !messages.isEmpty else { return nil }

        let conversationText = messages.map { "\($0.role.displayName): \($0.content)" }.joined(separator: "\n")

        let prompt = """
        あなたは高精度なパーソナルAIアシスタントの記憶管理モジュールです。
        以下の「ユーザーとの会話履歴」と「現在の既存記憶」を分析し、ユーザーに関する永続的に覚えておくべき重要な情報を抽出・更新してください。

        【分析ルール】
        1. ユーザーの性格、口調の好み、興味関心、趣味、習慣、仕事や技術的背景
        2. ユーザーが言及した重要事項、決定事項、前提条件
        3. 一時的な雑談のノイズは省き、将来の会話に役立つ本質的な事実のみを抽出
        4. 既存記憶と重複する内容は統合し、最新情報に更新

        以下のフォーマット（箇条書き）で出力してください（余計な挨拶や説明は不要です）:

        【👤 ユーザーの特徴・性格・背景】
        ・(例: プログラミングやAI開発に熱心、簡潔な回答を好む)
        【❤️ 好み・興味関心・趣味】
        ・(例: 音楽を聴くのが好き、漫画やアニメに関心がある)
        【🎯 プロジェクト・重要事項・決定事項】
        ・(例: AIトレーディングシステムの開発、静岡在住または関連)

        ---
        【現在の既存記憶】:
        \(currentMemory.isEmpty ? "（まだ記憶はありません）" : currentMemory)

        【会話履歴】:
        \(conversationText)
        """

        let requestMessages = [
            ChatMessage(role: .system, content: "あなたはユーザーの重要な特徴や記憶を箇条書きで抽出するエキスパートです。指定された形式のみを出力してください。"),
            ChatMessage(role: .user, content: prompt)
        ]

        do {
            let stream = await OllamaService.shared.sendChatStream(model: model, messages: requestMessages, think: false)
            var result = ""
            for try await token in stream {
                result += token
            }
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
}
