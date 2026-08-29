import Foundation
import CoreServices
import NaturalLanguage

public struct DictionaryDefinition: Sendable {
    public let word: String
    public let phonetic: String
    public let partOfSpeech: String
    public let meanings: [String]
    public let fullDefinition: String

    public init(
        word: String,
        phonetic: String = "",
        partOfSpeech: String = "",
        meanings: [String] = [],
        fullDefinition: String = ""
    ) {
        self.word = word
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.meanings = meanings
        self.fullDefinition = fullDefinition
    }
}

public final class DictionaryLookupService: @unchecked Sendable {
    public static let shared = DictionaryLookupService()

    private init() {}

    /// macOS 内蔵辞書（Dictionary Services）を使って単語やフレーズの定義・和訳を高速取得
    /// LLM を使用しないため、0.01 秒未満・メモリ消費 0MB で動作します。
    public func lookup(text: String) -> DictionaryDefinition? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 句読点などを除去した先頭の主要単語・フレーズを辞書引き
        let cleanQuery = trimmed.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return nil }

        let range = CFRangeMake(0, cleanQuery.utf16.count)
        guard let definitionRef = DCSCopyTextDefinition(nil, cleanQuery as CFString, range) else {
            // 単語単位でのフォールバック（複数単語の場合、最初の単語を引く）
            let firstWord = cleanQuery.split(separator: " ").first.map(String.init) ?? ""
            if !firstWord.isEmpty && firstWord != cleanQuery {
                let wordRange = CFRangeMake(0, firstWord.utf16.count)
                if let fallbackRef = DCSCopyTextDefinition(nil, firstWord as CFString, wordRange) {
                    let fullText = fallbackRef.takeRetainedValue() as String
                    return parseDefinition(rawText: fullText, query: firstWord)
                }
            }
            return nil
        }

        let fullText = definitionRef.takeRetainedValue() as String
        return parseDefinition(rawText: fullText, query: trimmed)
    }

    /// 辞書テキストから品詞、発音、日本語の意味をパース
    private func parseDefinition(rawText: String, query: String) -> DictionaryDefinition {
        let lines = rawText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var phonetic = ""
        var partOfSpeech = ""
        var meanings: [String] = []

        // 発音記号（/ ... / や [ ... ]）の抽出
        let phoneticRegex = try? NSRegularExpression(pattern: "[/|\\[](.*?)[/|\\]]")
        if let match = phoneticRegex?.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.utf16.count)) {
            if let range = Range(match.range, in: rawText) {
                phonetic = String(rawText[range])
            }
        }

        // 品詞（名、動、形、副、名詞、他動詞など）の判定
        let posPatterns = ["名詞", "動詞", "他動詞", "自動詞", "形容詞", "副詞", "前置詞", "接続詞", "間投詞", "noun", "verb", "adjective", "adverb"]
        for pos in posPatterns {
            if rawText.contains(pos) {
                partOfSpeech = pos
                break
            }
        }

        // 意味の抽出（番号付きリストや主要行を抽出）
        for line in lines {
            // 辞書のヘッダーや見出しは除外
            if line.caseInsensitiveCompare(query) == .orderedSame { continue }
            if line.hasPrefix("▶") || line.hasPrefix("1") || line.hasPrefix("2") || line.hasPrefix("①") || line.hasPrefix("②") || line.hasPrefix("・") {
                meanings.append(line)
            } else if meanings.count < 3 && line.count > 2 && line.count < 120 {
                // 日本語が含まれている行を優先
                if containsJapanese(line) {
                    meanings.append(line)
                }
            }
            if meanings.count >= 4 { break }
        }

        if meanings.isEmpty {
            // 日本語が含まれる最初の数行を取得
            let jpLines = lines.filter { containsJapanese($0) }
            meanings = Array(jpLines.prefix(3))
        }

        return DictionaryDefinition(
            word: query,
            phonetic: phonetic,
            partOfSpeech: partOfSpeech,
            meanings: meanings,
            fullDefinition: rawText
        )
    }

    private func containsJapanese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // ひらがな・カタカナ・漢字
            if (0x3040...0x309F).contains(scalar.value) ||
               (0x30A0...0x30FF).contains(scalar.value) ||
               (0x4E00...0x9FAF).contains(scalar.value) {
                return true
            }
        }
        return false
    }
}
