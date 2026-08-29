import Foundation

// MARK: - Open Notebook Models

public struct OpenNotebookItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let created: String?
    public let updated: String?
    public let archived: Bool?

    public init(id: String, name: String, description: String? = nil, created: String? = nil, updated: String? = nil, archived: Bool? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.created = created
        self.updated = updated
        self.archived = archived
    }
}

public struct OpenNotebookSource: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String?
    public let content: String?
    public let type: String?
    public let created: String?
    public let updated: String?
    public let embedded: Bool?

    public var displayTitle: String {
        title ?? id
    }
}

public struct OpenNotebookSearchResult: Codable, Identifiable, Hashable, Sendable {
    public var id: String {
        rawDict["id"] ?? UUID().uuidString
    }
    public let title: String
    public let content: String
    public let score: Double?
    public let type: String?
    public let rawDict: [String: String]

    public init(title: String, content: String, score: Double? = nil, type: String? = nil, rawDict: [String: String] = [:]) {
        self.title = title
        self.content = content
        self.score = score
        self.type = type
        self.rawDict = rawDict
    }
}

// MARK: - Local Obsidian Vault Note Item

public struct ObsidianNoteItem: Identifiable, Hashable, Sendable {
    public var id: String { relPath }
    public let relPath: String
    public let title: String
    public let url: URL
    public let modifiedDate: Date
    public let fileSize: Int64

    public init(relPath: String, title: String, url: URL, modifiedDate: Date, fileSize: Int64) {
        self.relPath = relPath
        self.title = title
        self.url = url
        self.modifiedDate = modifiedDate
        self.fileSize = fileSize
    }
}
