import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system

    public var displayName: String {
        switch self {
        case .user: return "ユーザー"
        case .assistant: return "アシスタント"
        case .system: return "システム"
        }
    }
}

public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var role: MessageRole
    public var content: String
    public var timestamp: Date
    public var isStreaming: Bool
    public var imageDataList: [Data]
    public var referencedRagSources: [OpenNotebookSearchResult]
    public var referencedWebSources: [WebSearchResultItem]

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageDataList: [Data] = [],
        referencedRagSources: [OpenNotebookSearchResult] = [],
        referencedWebSources: [WebSearchResultItem] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageDataList = imageDataList
        self.referencedRagSources = referencedRagSources
        self.referencedWebSources = referencedWebSources
    }
}
