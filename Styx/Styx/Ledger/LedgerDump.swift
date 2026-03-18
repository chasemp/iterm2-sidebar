import Foundation

// MARK: - Dump Models

struct LedgerSummaryEntry: Codable {
    let id: String
    let timestamp: Date
    let component: String
    let operation: String
    let outcome: String
    let durationMs: UInt32?
    let stateChanged: Bool
    let errorMessage: String?
}

struct LedgerSummary: Codable {
    let dumpTimestamp: Date
    let windowStart: Date?
    let windowEnd: Date?
    let transitionCount: Int
    let componentBreakdown: [String: Int]
    let chainBreaks: [ChainBreak]
    let currentState: [String: AnyCodable]?
    let serializationMetrics: SerializationMetrics?
    let entries: [LedgerSummaryEntry]
}

struct ChainBreak: Codable {
    let afterTransitionId: String
    let beforeTransitionId: String
    let component: String
    let mismatchedKeys: [String]
}

struct LedgerManifestEntry: Codable {
    let id: String
    let component: String
    let operation: String
    let filename: String
}

struct LedgerManifest: Codable {
    let transitionCount: Int
    let entries: [LedgerManifestEntry]
}

struct SerializationMetrics: Codable {
    let totalSerializationMs: Double
    let averagePerTransitionMs: Double
    let totalDumpBytes: Int
    let transitionCount: Int
    let note: String
}

// MARK: - Dump Writer

enum LedgerDumpWriter {

    @MainActor
    static func writeDump(
        from ledger: StateLedger,
        to baseURL: URL,
        dirName: String? = nil
    ) throws -> URL {
        let name = dirName ?? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return "ledger-\(formatter.string(from: Date()))"
                .replacingOccurrences(of: ":", with: "-")
        }()
        let dumpDir = baseURL.appendingPathComponent(name)
        let transitionsDir = dumpDir.appendingPathComponent("transitions")

        try FileManager.default.createDirectory(at: transitionsDir, withIntermediateDirectories: true)

        let entries = ledger.allEntries()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let serStart = CFAbsoluteTimeGetCurrent()

        var manifestEntries: [LedgerManifestEntry] = []
        var totalBytes = 0

        for (index, transition) in entries.enumerated() {
            let filename = String(format: "%03d-%@-%@.json", index + 1, transition.component, transition.operation)
            let filePath = transitionsDir.appendingPathComponent(filename)
            let data = try encoder.encode(transition)
            try data.write(to: filePath)
            totalBytes += data.count

            manifestEntries.append(LedgerManifestEntry(
                id: transition.id.uuidString,
                component: transition.component,
                operation: transition.operation,
                filename: "transitions/\(filename)"
            ))
        }

        let serElapsed = (CFAbsoluteTimeGetCurrent() - serStart) * 1000

        var componentBreakdown: [String: Int] = [:]
        let summaryEntries: [LedgerSummaryEntry] = entries.map { t in
            componentBreakdown[t.component, default: 0] += 1
            let stateChanged = !NSDictionary(dictionary: t.beforeState.mapValues { "\($0)" })
                .isEqual(to: t.afterState.mapValues { "\($0)" })
            return LedgerSummaryEntry(
                id: t.id.uuidString,
                timestamp: t.timestamp,
                component: t.component,
                operation: t.operation,
                outcome: t.outcome.rawValue,
                durationMs: t.durationMs,
                stateChanged: stateChanged,
                errorMessage: t.errorMessage
            )
        }

        let metrics = SerializationMetrics(
            totalSerializationMs: serElapsed,
            averagePerTransitionMs: entries.isEmpty ? 0 : serElapsed / Double(entries.count),
            totalDumpBytes: totalBytes,
            transitionCount: entries.count,
            note: "Codable+JSON. If avg > 1ms or totalBytes > 50MB, evaluate Protobuf."
        )

        var chainBreaks: [ChainBreak] = []
        var lastAfterByComponent: [String: (id: String, state: [String: AnyCodable])] = [:]
        for t in entries {
            if let prev = lastAfterByComponent[t.component] {
                let prevKeys = Set(prev.state.keys)
                let curKeys = Set(t.beforeState.keys)
                let commonKeys = prevKeys.intersection(curKeys)
                let mismatched = commonKeys.filter { "\(prev.state[$0]!)" != "\(t.beforeState[$0]!)" }
                if !mismatched.isEmpty {
                    chainBreaks.append(ChainBreak(
                        afterTransitionId: prev.id,
                        beforeTransitionId: t.id.uuidString,
                        component: t.component,
                        mismatchedKeys: Array(mismatched).sorted()
                    ))
                }
            }
            lastAfterByComponent[t.component] = (t.id.uuidString, t.afterState)
        }

        let currentState = ledger.currentStateProvider?()

        let summary = LedgerSummary(
            dumpTimestamp: Date(),
            windowStart: entries.first?.timestamp,
            windowEnd: entries.last?.timestamp,
            transitionCount: entries.count,
            componentBreakdown: componentBreakdown,
            chainBreaks: chainBreaks,
            currentState: currentState,
            serializationMetrics: metrics,
            entries: summaryEntries
        )

        let summaryData = try encoder.encode(summary)
        try summaryData.write(to: dumpDir.appendingPathComponent("summary.json"))

        let manifest = LedgerManifest(
            transitionCount: entries.count,
            entries: manifestEntries
        )
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: dumpDir.appendingPathComponent("manifest.json"))

        return dumpDir
    }
}
