import Foundation

enum TransitionOutcome: String, Codable, Equatable, Sendable {
    case success
    case failure
    case partial
    case timeout
}

struct StateTransition: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let component: String
    let operation: String
    let beforeState: [String: AnyCodable]
    let afterState: [String: AnyCodable]
    let durationMs: UInt32?
    let outcome: TransitionOutcome
    let metadata: [String: String]
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        component: String,
        operation: String,
        beforeState: [String: AnyCodable],
        afterState: [String: AnyCodable],
        durationMs: UInt32?,
        outcome: TransitionOutcome,
        metadata: [String: String],
        errorMessage: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.component = component
        self.operation = operation
        self.beforeState = beforeState
        self.afterState = afterState
        self.durationMs = durationMs
        self.outcome = outcome
        self.metadata = metadata
        self.errorMessage = errorMessage
    }
}
