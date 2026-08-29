import Foundation
import AVFoundation
import SwiftUI

@MainActor
public final class EnglishLearningService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = EnglishLearningService()

    @Published public var vocabularyItems: [VocabItem] = []
    @Published public var isSpeakingNative: Bool = false
    @Published public var activeHUDItem: VocabItem? = nil

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let storageKey = "MyOllama.VocabularyList"

    override private init() {
        super.init()
        speechSynthesizer.delegate = self
        loadVocabulary()
    }

    // MARK: - 🔊 ネイティブ英語音声読み上げ (Native Pronunciation)

    private var nsSpeechSynth: NSSpeechSynthesizer?
    @Published public var selectedEnglishVoiceName: String = "Samantha" // "Samantha" (US), "Daniel" (GB), "Karen" (AU)

    public func speakNativeEnglish(text: String, rate: Float = 0.48) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        // 1. NSSpeechSynthesizer での確実なネイティブ再生
        if nsSpeechSynth == nil {
            nsSpeechSynth = NSSpeechSynthesizer()
        }

        if let synth = nsSpeechSynth {
            // 高品質な自然ボイス（Samantha > Daniel > Karen > Alex）を厳選
            let preferredVoices = ["Samantha", "Daniel", "Karen", "Alex", "Victoria"]
            var targetVoice: NSSpeechSynthesizer.VoiceName? = nil

            // ユーザー指定ボイスを探す
            for voice in NSSpeechSynthesizer.availableVoices {
                let attr = NSSpeechSynthesizer.attributes(forVoice: voice)
                let name = attr[.name] as? String ?? ""
                if name.localizedCaseInsensitiveContains(selectedEnglishVoiceName) {
                    targetVoice = voice
                    break
                }
            }

            // 指定が無ければ優先リストから探す
            if targetVoice == nil {
                for pref in preferredVoices {
                    if let found = NSSpeechSynthesizer.availableVoices.first(where: { v in
                        let attr = NSSpeechSynthesizer.attributes(forVoice: v)
                        let name = attr[.name] as? String ?? ""
                        return name.localizedCaseInsensitiveContains(pref)
                    }) {
                        targetVoice = found
                        break
                    }
                }
            }

            if let voice = targetVoice {
                synth.setVoice(voice)
            }
            synth.rate = 175 // 聞き取りやすいネイティブ自然速度

            synth.stopSpeaking()
            self.isSpeakingNative = true
            synth.startSpeaking(cleanText)
            return
        }

        // 2. AVSpeechSynthesizer フォールバック
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: cleanText)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: { $0.name.contains("Samantha") || $0.language == "en-US" }) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        self.isSpeakingNative = true
        speechSynthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        nsSpeechSynth?.stopSpeaking()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeakingNative = false
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeakingNative = false
        }
    }

    // MARK: - 📚 単語帳管理 (Vocabulary Manager)

    public func addVocabularyItem(
        word: String,
        phonetic: String = "",
        partOfSpeech: String = "",
        meaning: String,
        exampleSentence: String = "",
        exampleTranslation: String = ""
    ) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        // 重複チェック（既存なら更新）
        if let index = vocabularyItems.firstIndex(where: { $0.word.lowercased() == trimmedWord.lowercased() }) {
            vocabularyItems[index].phonetic = phonetic.isEmpty ? vocabularyItems[index].phonetic : phonetic
            vocabularyItems[index].partOfSpeech = partOfSpeech.isEmpty ? vocabularyItems[index].partOfSpeech : partOfSpeech
            vocabularyItems[index].meaning = meaning.isEmpty ? vocabularyItems[index].meaning : meaning
            vocabularyItems[index].exampleSentence = exampleSentence.isEmpty ? vocabularyItems[index].exampleSentence : exampleSentence
            vocabularyItems[index].exampleTranslation = exampleTranslation.isEmpty ? vocabularyItems[index].exampleTranslation : exampleTranslation
        } else {
            let newItem = VocabItem(
                word: trimmedWord,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                meaning: meaning,
                exampleSentence: exampleSentence,
                exampleTranslation: exampleTranslation
            )
            vocabularyItems.insert(newItem, at: 0)
        }
        saveVocabulary()
    }

    public func toggleMastered(id: UUID) {
        if let index = vocabularyItems.firstIndex(where: { $0.id == id }) {
            vocabularyItems[index].isMastered.toggle()
            saveVocabulary()
        }
    }

    public func deleteItem(id: UUID) {
        vocabularyItems.removeAll(where: { $0.id == id })
        saveVocabulary()
    }

    private func saveVocabulary() {
        if let data = try? JSONEncoder().encode(vocabularyItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadVocabulary() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([VocabItem].self, from: data) {
            self.vocabularyItems = items
        } else {
            // 初期デモ単語
            self.vocabularyItems = [
                VocabItem(word: "architecture", phonetic: "/ˈɑːrkɪtɛktʃər/", partOfSpeech: "名詞", meaning: "構造、建築様式、設計思想", exampleSentence: "We designed a modular agent architecture.", exampleTranslation: "モジュール化されたエージェント構造を設計しました。"),
                VocabItem(word: "autonomous", phonetic: "/ɔːˈtɒnəməs/", partOfSpeech: "形容詞", meaning: "自律的な、自主的な", exampleSentence: "The AI agent performs autonomous operations.", exampleTranslation: "そのAIエージェントは自律的な操作を実行します。")
            ]
        }
    }

    // MARK: - 💾 Obsidian への単語帳エクスポート

    @discardableResult
    public func exportToObsidian() -> (success: Bool, path: String?) {
        let myOllamaURL = ObsidianChatExportService.shared.getMyOllamaVaultDirectory()
        let fileURL = myOllamaURL.appendingPathComponent("vocabulary.md")
        var mdContent = """
        # 📚 英語学習・単語帳 (My Vocabulary)
        最終更新: \(Date().formatted())
        総単語数: \(vocabularyItems.count)件 (覚えた: \(vocabularyItems.filter { $0.isMastered }.count)件)

        | 習得 | 単語 / イディオム | 発音記号 | 品詞 | 意味 | 例文 | 例文訳 |
        | :---: | :--- | :--- | :--- | :--- | :--- | :--- |

        """

        for item in vocabularyItems {
            let check = item.isMastered ? "✅" : "⏳"
            let escapedWord = item.word.replacingOccurrences(of: "|", with: "\\|")
            let escapedPhonetic = item.phonetic.replacingOccurrences(of: "|", with: "\\|")
            let escapedPOS = item.partOfSpeech.replacingOccurrences(of: "|", with: "\\|")
            let escapedMeaning = item.meaning.replacingOccurrences(of: "|", with: "\\|")
            let escapedEx = item.exampleSentence.replacingOccurrences(of: "|", with: "\\|")
            let escapedTr = item.exampleTranslation.replacingOccurrences(of: "|", with: "\\|")

            mdContent += "| \(check) | **\(escapedWord)** | `\(escapedPhonetic)` | \(escapedPOS) | \(escapedMeaning) | \(escapedEx) | \(escapedTr) |\n"
        }

        do {
            try mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return (true, fileURL.path)
        } catch {
            return (false, nil)
        }
    }

    // MARK: - 🧠 英語学習・詳細解説プロンプト構築

    public func buildEnglishAnalysisPrompt(text: String) -> String {
        return """
        以下の英文または英単語について、英語学習者のために分かりやすく詳細に解説してください。
        語尾はずんだもん口調（〜なのだ、〜のだ）を適度に交えつつ、解説は論理的かつ明確に構造化してください。

        【対象の英文 / 単語】:
        \(text)

        ---
        以下のフォーマットに従って回答を出力してください：

        ### 🔤 1. 翻訳
        ・**直訳（構文がわかる逐語訳）**: [直訳]
        ・**自然な意訳（流暢な日本語）**: [意訳]

        ### 📖 2. 重要単語・イディオムリスト
        | 単語/フレーズ | 発音記号 (IPA) | 品詞 | 意味 |
        | :--- | :--- | :--- | :--- |
        | [単語1] | /[発音]/ | [品詞] | [意味] |

        ### 🧩 3. 文法・構文の徹底解説
        ・**文構造 (S+V+O+C)**: [主語、述語動詞、目的語などの分解]
        ・**文法のポイント**: [関係代名詞、時制、助動詞、仮定法などの構文上のポイント解説]
        ・**ニュアンス・実務での使われ方**: [ネイティブのニュアンスや使われる場面]

        ### 💡 4. 応用例文
        ・**例文 (English)**: [例文]
        ・**和訳**: [例文の日本語訳]
        """
    }
}
