import Foundation

@MainActor
final class StateLedger {

    static let shared = StateLedger()

    let windowDuration: TimeInterval = 600  // 10 minutes

    private var buffer: [StateTransition] = []
    private var dumpDebounceTask: Task<Void, Never>?

    static let latestDumpURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Styx/ledger-dumps/latest")
    }()

    private init() {}

    private func scheduleDump() {
        dumpDebounceTask?.cancel()
        dumpDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.writeToDisk()
        }
    }

    private func writeToDisk() {
        guard !buffer.isEmpty else { return }
        do {
            let url = Self.latestDumpURL
            try? FileManager.default.removeItem(at: url)
            _ = try LedgerDumpWriter.writeDump(from: self, to: url.deletingLastPathComponent(), dirName: "latest")
        } catch {
            print("[StateLedger] Auto-dump failed: \(error)")
        }
    }

    // MARK: - Public interface

    var entryCount: Int { buffer.count }

    func record(
        component: String,
        operation: String,
        before: [String: AnyCodable],
        after: [String: AnyCodable],
        durationMs: UInt32?,
        outcome: TransitionOutcome,
        metadata: [String: String],
        errorMessage: String?
    ) {
        prune()
        let transition = StateTransition(
            component: component,
            operation: operation,
            beforeState: before,
            afterState: after,
            durationMs: durationMs,
            outcome: outcome,
            metadata: metadata,
            errorMessage: errorMessage
        )
        buffer.append(transition)
        scheduleDump()
    }

    func entries(for component: String) -> [StateTransition] {
        buffer.filter { $0.component == component }
    }

    func allEntries() -> [StateTransition] {
        prune()
        return buffer
    }

    func record(
        component: String,
        operation: String,
        before: [String: AnyCodable],
        after: [String: AnyCodable],
        outcome: TransitionOutcome = .success,
        metadata: [String: String] = [:],
        errorMessage: String? = nil
    ) {
        record(component: component, operation: operation,
               before: before, after: after,
               durationMs: nil, outcome: outcome,
               metadata: metadata, errorMessage: errorMessage)
    }

    func timed<T>(
        component: String,
        operation: String,
        before: [String: AnyCodable],
        metadata: [String: String] = [:],
        body: () async throws -> (T, [String: AnyCodable])
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (result, after) = try await body()
            let elapsed = UInt32((CFAbsoluteTimeGetCurrent() - start) * 1000)
            record(component: component, operation: operation,
                   before: before, after: after,
                   durationMs: elapsed, outcome: .success,
                   metadata: metadata, errorMessage: nil)
            return result
        } catch {
            let elapsed = UInt32((CFAbsoluteTimeGetCurrent() - start) * 1000)
            record(component: component, operation: operation,
                   before: before, after: before,
                   durationMs: elapsed, outcome: .failure,
                   metadata: metadata, errorMessage: error.localizedDescription)
            throw error
        }
    }

    var currentStateProvider: (() -> [String: AnyCodable])?

    func prune() {
        let cutoff = Date().addingTimeInterval(-windowDuration)
        buffer = buffer.filter { $0.timestamp >= cutoff }
    }

    func clear() {
        buffer.removeAll()
    }

    func injectForTesting(_ transition: StateTransition) {
        buffer.append(transition)
    }
}
