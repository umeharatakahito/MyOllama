import Foundation
import SwiftUI

public enum AgentTargetTool: String, CaseIterable, Identifiable, Codable, Sendable {
    case aiTrading = "AI-trading"
    case umeLunch = "ume-lunch"
    case obsidian = "Obsidian"
    case general = "General"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .aiTrading: return "chart.line.uptrend.xyaxis"
        case .umeLunch: return "play.square.stack.fill"
        case .obsidian: return "book.pages.fill"
        case .general: return "cpu.fill"
        }
    }

    public var color: Color {
        switch self {
        case .aiTrading: return .green
        case .umeLunch: return .orange
        case .obsidian: return .cyan
        case .general: return .purple
        }
    }
}

public enum AgentTaskStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case pending = "未着手"
    case inProgress = "実行中"
    case completed = "完了"
    case failed = "エラー"
    case skipped = "スキップ"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .pending: return "hourglass.bottomhalf.filled"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.octagon.fill"
        case .skipped: return "forward.frame.fill"
        }
    }

    public var color: Color {
        switch self {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

public struct AgentTask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var targetTool: AgentTargetTool
    public var command: String?
    public var status: AgentTaskStatus
    public var dependencyIds: [UUID]
    public var logs: [String]
    public var progress: Double // 0.0 ~ 1.0
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        targetTool: AgentTargetTool,
        command: String? = nil,
        status: AgentTaskStatus = .pending,
        dependencyIds: [UUID] = [],
        logs: [String] = [],
        progress: Double = 0.0,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.targetTool = targetTool
        self.command = command
        self.status = status
        self.dependencyIds = dependencyIds
        self.logs = logs
        self.progress = progress
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var executionDuration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = finishedAt ?? Date()
        return end.timeIntervalSince(start)
    }
}
