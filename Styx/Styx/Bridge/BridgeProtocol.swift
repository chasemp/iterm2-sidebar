import Foundation

// MARK: - Bridge Service Protocol

protocol BridgeService: Actor {
    func start() throws
    func stop()
    func call(_ cmd: String, args: [String: Any]) async throws -> Any?
}

// MARK: - Errors

enum BridgeError: LocalizedError {
    case notRunning
    case disconnected
    case encodingFailed
    case remoteError(String)
    case processExited(Int32)

    var errorDescription: String? {
        switch self {
        case .notRunning: "Bridge daemon is not running"
        case .disconnected: "Bridge daemon disconnected"
        case .encodingFailed: "Failed to encode request"
        case .remoteError(let msg): "Bridge error: \(msg)"
        case .processExited(let code): "Bridge daemon exited with code \(code)"
        }
    }
}

// MARK: - Request/Response

struct BridgeRequest: Codable {
    let id: String
    let cmd: String
    let args: [String: AnyCodable]

    init(cmd: String, args: [String: Any] = [:]) {
        self.id = "req-\(UUID().uuidString.prefix(8))"
        self.cmd = cmd
        self.args = args.mapValues { AnyCodable($0) }
    }
}

struct BridgeResponse: Codable {
    let id: String?
    let ok: Bool?
    let data: AnyCodable?
    let error: String?
    let event: String?

    var isEvent: Bool { event != nil }
    var isSuccess: Bool { ok == true }
}

// MARK: - Focus Events

struct FocusEvent {
    enum Kind: String {
        case window, tab, session
    }

    let kind: Kind
    let windowId: String?
    let tabId: String?
    let sessionId: String?

    init(kind: Kind, windowId: String? = nil, tabId: String? = nil, sessionId: String? = nil) {
        self.kind = kind
        self.windowId = windowId
        self.tabId = tabId
        self.sessionId = sessionId
    }

    init?(from response: BridgeResponse) {
        guard response.event == "focus_changed",
              let data = response.data?.value as? [String: Any],
              let typeStr = data["type"] as? String,
              let kind = Kind(rawValue: typeStr) else {
            return nil
        }
        self.kind = kind
        self.windowId = data["window_id"] as? String
        self.tabId = data["tab_id"] as? String
        self.sessionId = data["session_id"] as? String
    }
}

// MARK: - Type-Erased Codable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
