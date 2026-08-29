import Foundation

// MARK: - Ollama Tags (Models List) API Models

public struct OllamaTagsResponse: Codable, Sendable {
    public let models: [OllamaModelInfo]
}

public struct OllamaModelInfo: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let model: String?
    public let size: Int64?
    public let modifiedAt: String?
    public let details: OllamaModelDetails?
    public let capabilities: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case model
        case size
        case modifiedAt = "modified_at"
        case details
        case capabilities
    }

    public var isVisionSupported: Bool {
        if let caps = capabilities {
            return caps.contains("vision")
        }
        let lower = name.lowercased()
        return lower.contains("vision") || lower.contains("llava") || lower.contains("minicpm") || lower.contains("bakllava")
    }

    public var formattedSize: String {
        guard let size = size, size > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

public struct OllamaModelDetails: Codable, Hashable, Sendable {
    public let format: String?
    public let family: String?
    public let parameterSize: String?
    public let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case format
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

// MARK: - Ollama Chat API Models

public struct OllamaChatRequest: Codable, Sendable {
    public let model: String
    public let messages: [OllamaMessagePayload]
    public let stream: Bool
    public let think: Bool?

    public init(model: String, messages: [OllamaMessagePayload], stream: Bool = true, think: Bool? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.think = think
    }
}

public struct OllamaMessagePayload: Codable, Sendable {
    public let role: String
    public let content: String
    public let images: [String]?

    public init(role: String, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }
}

public struct OllamaChatStreamChunk: Codable, Sendable {
    public let model: String?
    public let message: OllamaMessagePayload?
    public let done: Bool?
    public let error: String?
    public let totalDuration: Int64?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case error
        case totalDuration = "total_duration"
    }
}

public struct OllamaErrorResponse: Codable, Sendable {
    public let error: String?
}
