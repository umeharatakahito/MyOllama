import Foundation
import SwiftUI
import Combine

// MARK: - 翻訳履歴アイテムモデル
public struct TranslationHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sourceText: String
    public var definition: String
    public var phonetic: String
    public var partOfSpeech: String
    public var source: String // "画面選択 (Cmd+Shift+S)", "クリップボード (Cmd+Shift+E)", "手動"
    public var isBookmarked: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourceText: String,
        definition: String = "",
        phonetic: String = "",
        partOfSpeech: String = "",
        source: String = "画面選択",
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceText = sourceText
        self.definition = definition
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.source = source
        self.isBookmarked = isBookmarked
    }
}

// MARK: - 翻訳履歴蓄積サービス (Translation History Database)
@MainActor
public final class TranslationHistoryService: ObservableObject {
    public static let shared = TranslationHistoryService()

    private let storageKey = "MyOllama.TranslationHistory"
    private let maxHistoryCount = 2000 // 最大2,000件の履歴を保持

    @Published public var historyItems: [TranslationHistoryItem] = []

    private init() {
        loadHistory()
    }

    // MARK: - 📝 履歴の自動記録
    public func recordHistory(
        sourceText: String,
        definition: String = "",
        phonetic: String = "",
        partOfSpeech: String = "",
        source: String = "画面選択"
    ) {
        let cleanText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        // 単語帳に追加されているか確認
        let isAlreadyVocab = EnglishLearningService.shared.vocabularyItems.contains {
            $0.word.lowercased() == cleanText.lowercased()
        }

        // 直近同じ単語が記録されている場合は更新して先頭へ
        if let index = historyItems.firstIndex(where: { $0.sourceText.lowercased() == cleanText.lowercased() }) {
            var existing = historyItems.remove(at: index)
            existing.definition = definition.isEmpty ? existing.definition : definition
            existing.phonetic = phonetic.isEmpty ? existing.phonetic : phonetic
            existing.partOfSpeech = partOfSpeech.isEmpty ? existing.partOfSpeech : partOfSpeech
            existing.source = source
            existing.isBookmarked = isAlreadyVocab
            historyItems.insert(existing, at: 0)
        } else {
            let newItem = TranslationHistoryItem(
                sourceText: cleanText,
                definition: definition,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                source: source,
                isBookmarked: isAlreadyVocab
            )
            historyItems.insert(newItem, at: 0)
        }

        // 上限件数制御
        if historyItems.count > maxHistoryCount {
            historyItems = Array(historyItems.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    // MARK: - ⭐️ 単語帳に追加 / 解除
    public func toggleBookmark(for item: TranslationHistoryItem) {
        if let index = historyItems.firstIndex(where: { $0.id == item.id }) {
            historyItems[index].isBookmarked.toggle()
            let bookmarked = historyItems[index].isBookmarked

            if bookmarked {
                // 単語帳に登録
                EnglishLearningService.shared.addVocabularyItem(
                    word: item.sourceText,
                    phonetic: item.phonetic,
                    partOfSpeech: item.partOfSpeech,
                    meaning: item.definition
                )
            }
            saveHistory()
        }
    }

    // MARK: - 🗑️ 履歴の削除
    public func deleteItem(id: UUID) {
        historyItems.removeAll(where: { $0.id == id })
        saveHistory()
    }

    public func clearAllHistory() {
        historyItems.removeAll()
        saveHistory()
    }

    // MARK: - 💾 永続化 (UserDefaults)
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([TranslationHistoryItem].self, from: data) {
            self.historyItems = items
        } else {
            self.historyItems = []
        }
    }

    // MARK: - 📚 Obsidian への翻訳履歴エクスポート
    @discardableResult
    public func exportToObsidian() -> (success: Bool, path: String?) {
        let myOllamaURL = ObsidianChatExportService.shared.getMyOllamaVaultDirectory()
        let fileURL = myOllamaURL.appendingPathComponent("translation_history.md")

        var mdContent = """
        # 🕒 翻訳・英単語検索ログ (Translation History)
        最終更新: \(Date().formatted())
        総件数: \(historyItems.count)件

        | 日時 | 原文 (単語・英文) | 意味・定義 | 発音 | 区分 |
        | :--- | :--- | :--- | :--- | :--- |

        """

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for item in historyItems {
            let dateStr = dateFormatter.string(from: item.timestamp)
            let escapedSource = item.sourceText.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "|", with: "\\|")
            let escapedDef = item.definition.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "|", with: "\\|")
            let escapedPhonetic = item.phonetic.replacingOccurrences(of: "|", with: "\\|")
            let sourceTag = item.source

            mdContent += "| \(dateStr) | **\(escapedSource)** | \(escapedDef) | `\(escapedPhonetic)` | \(sourceTag) |\n"
        }

        do {
            try mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return (true, fileURL.path)
        } catch {
            return (false, nil)
        }
    }
}
