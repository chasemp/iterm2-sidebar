import Foundation
import os

actor ITerm2Bridge: BridgeService {
    private let logger = Logger(subsystem: "com.styx.bridge", category: "ITerm2Bridge")

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var pendingRequests: [String: CheckedContinuation<BridgeResponse, Error>] = [:]
    private var focusContinuation: AsyncStream<FocusEvent>.Continuation?
    private var readTask: Task<Void, Never>?
    private var isRunning = false
    private var pythonPath: String

    nonisolated let focusEvents: AsyncStream<FocusEvent>

    init(pythonPath: String = "/usr/bin/env") {
        self.pythonPath = pythonPath
        var continuation: AsyncStream<FocusEvent>.Continuation!
        self.focusEvents = AsyncStream { continuation = $0 }
        self.focusContinuation = continuation
    }

    func start() throws {
        guard !isRunning else { return }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["python3", bridgeScriptPath()]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        process.environment = ProcessInfo.processInfo.environment

        process.terminationHandler = { [weak self] proc in
            Task { [weak self] in
                await self?.handleTermination(exitCode: proc.terminationStatus)
            }
        }

        try process.run()

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.isRunning = true
        startReadingStdout()
    }

    func stop() {
        isRunning = false
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil

        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: BridgeError.disconnected)
        }
        pendingRequests.removeAll()
    }

    func call(_ cmd: String, args: [String: Any] = [:]) async throws -> Any? {
        guard isRunning, let stdinPipe else { throw BridgeError.notRunning }

        let request = BridgeRequest(cmd: cmd, args: args)
        let data = try JSONEncoder().encode(request)
        guard var jsonLine = String(data: data, encoding: .utf8) else { throw BridgeError.encodingFailed }
        jsonLine.append("\n")

        let response: BridgeResponse = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = continuation
            stdinPipe.fileHandleForWriting.write(jsonLine.data(using: .utf8)!)
        }

        if let error = response.error { throw BridgeError.remoteError(error) }
        return response.data?.value
    }

    private func startReadingStdout() {
        guard let handle = stdoutPipe?.fileHandleForReading else { return }
        readTask = Task.detached { [weak self] in
            var buffer = Data()
            let newline = UInt8(ascii: "\n")
            while !Task.isCancelled {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let idx = buffer.firstIndex(of: newline) {
                    let lineData = buffer[buffer.startIndex..<idx]
                    buffer = Data(buffer[buffer.index(after: idx)...])
                    guard let self else { return }
                    if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                        await self.handleLine(line)
                    }
                }
            }
        }
    }

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        do {
            let response = try JSONDecoder().decode(BridgeResponse.self, from: data)
            if response.isEvent {
                if let event = FocusEvent(from: response) { focusContinuation?.yield(event) }
            } else if let id = response.id, let continuation = pendingRequests.removeValue(forKey: id) {
                continuation.resume(returning: response)
            }
        } catch {
            logger.error("Failed to decode bridge response: \(error)")
        }
    }

    private func handleTermination(exitCode: Int32) {
        isRunning = false
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: BridgeError.processExited(exitCode))
        }
        pendingRequests.removeAll()

        Task {
            try await Task.sleep(for: .seconds(2))
            do { try self.start() } catch {
                logger.error("Failed to restart bridge: \(error)")
            }
        }
    }

    private func bridgeScriptPath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "bridge_daemon", ofType: "py", inDirectory: "StyxBridge") {
            return bundlePath
        }
        return Bundle.main.bundlePath
            .components(separatedBy: "/").dropLast(1).joined(separator: "/")
            + "/StyxBridge/bridge_daemon.py"
    }
}
