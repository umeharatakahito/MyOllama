import Foundation

public struct CanvasDocument: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var fileURL: URL?
    public var isModified: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        fileURL: URL? = nil,
        isModified: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.isModified = isModified
    }
}
