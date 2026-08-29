import Foundation

@MainActor
public final class ObsidianChatExportService: ObservableObject {
    public static let shared = ObsidianChatExportService()

    private init() {}

    /// 保存先ディレクトリのURLを取得（存在しない場合は自動作成）
    public func getMyOllamaVaultDirectory() -> URL {
        let vaultRoot = OpenNotebookService.defaultObsidianVaultPath
        let myOllamaURL = URL(fileURLWithPath: vaultRoot).appendingPathComponent("myollama")
        try? FileManager.default.createDirectory(at: myOllamaURL, withIntermediateDirectories: true)
        return myOllamaURL
    }

    /// 会話履歴からタイトルと要約を生成し、Obsidian の myollama フォルダに MD ファイルとして保存
    public func saveChatToObsidian(
        messages: [ChatMessage],
        model: String,
        personaName: String
    ) async -> (success: Bool, fileName: String?, summary: String?) {
        guard !messages.isEmpty else { return (false, nil, nil) }

        let conversationText = messages.map { "\($0.role.displayName): \($0.content)" }.joined(separator: "\n")

        // 1. タイトルと要約をLLMで生成
        let prompt = """
        以下の会話履歴を分析し、Obsidianノート用の「タイトル」と「構造化まとめ」を作成してください。

        【出力フォーマット（厳密に従ってください）】
        TITLE: [会話内容を表す具体的で簡潔な日本語タイトル（20文字以内、記号なし）]
        SUMMARY:
        ・[要点1: 話し合われた主題]
        ・[要点2: 重要な決定事項や結論]
        ・[要点3: 次のアクションや得られた知見]

        【会話履歴】:
        \(conversationText)
        """

        var generatedTitle = "会話ログ"
        var generatedSummary = "（要約なし）"

        let requestMessages = [
            ChatMessage(role: .system, content: "あなたは会話を要約しタイトルを付けるエキスパートです。指定されたフォーマットのみを出力してください。"),
            ChatMessage(role: .user, content: prompt)
        ]

        do {
            let stream = await OllamaService.shared.sendChatStream(model: model, messages: requestMessages, think: false)
            var fullResponse = ""
            for try await token in stream {
                fullResponse += token
            }

            let lines = fullResponse.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("TITLE:") {
                    let t = line.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        generatedTitle = t.replacingOccurrences(of: "/", with: "-")
                            .replacingOccurrences(of: ":", with: "-")
                            .replacingOccurrences(of: "\\", with: "-")
                    }
                }
            }

            if let summaryRange = fullResponse.range(of: "SUMMARY:") {
                generatedSummary = String(fullResponse[summaryRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // 生成失敗時はデフォルト
        }

        // 2. Markdown 本文の組み立て
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let nowString = dateFormatter.string(from: Date())

        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let fileDateString = fileDateFormatter.string(from: Date())

        let fileName = "\(fileDateString)_\(generatedTitle).md"

        var mdContent = """
        ---
        title: "\(generatedTitle)"
        date: \(nowString)
        model: \(model)
        persona: \(personaName)
        tags:
          - myollama
          - ai-chat
          - obsidian
          - summary
        ---

        # 💬 \(generatedTitle)

        > 📅 **記録日時**: \(nowString)  
        > 🤖 **モデル**: `\(model)` ｜ 🎭 **ペルソナ**: `\(personaName)`

        ---

        ## 📌 会話の要約・重要ポイント
        \(generatedSummary)

        ---

        ## 💬 詳細会話ログ（全文トランスクリプト）

        """

        for msg in messages {
            let roleIcon = (msg.role == .user) ? "👤" : "🌱"
            let timeStr = msg.timestamp.formatted(date: .omitted, time: .shortened)
            mdContent += "\n### \(roleIcon) \(msg.role.displayName) (\(timeStr))\n"
            mdContent += "\(msg.content)\n"
        }

        // 3. ファイルへの書き込み
        let dir = getMyOllamaVaultDirectory()
        let fileURL = dir.appendingPathComponent(fileName)

        do {
            try mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
            OpenNotebookService.shared.loadObsidianNotes()
            return (true, fileName, generatedSummary)
        } catch {
            return (false, nil, nil)
        }
    }
}
