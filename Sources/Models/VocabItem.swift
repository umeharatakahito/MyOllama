import Foundation
import SwiftUI

public struct VocabItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var word: String
    public var phonetic: String // 発音記号 (例: /ˈprɒdʒɛkt/)
    public var partOfSpeech: String // 品詞 (名詞, 動詞, 形容詞等)
    public var meaning: String // 日本語の意味
    public var exampleSentence: String // 例文
    public var exampleTranslation: String // 例文の日本語訳
    public var isMastered: Bool // 覚えたかどうか
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        word: String,
        phonetic: String = "",
        partOfSpeech: String = "",
        meaning: String,
        exampleSentence: String = "",
        exampleTranslation: String = "",
        isMastered: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.isMastered = isMastered
        self.createdAt = createdAt
    }
}
