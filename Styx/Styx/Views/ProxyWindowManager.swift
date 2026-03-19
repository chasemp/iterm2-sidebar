import AppKit
import SwiftUI

/// Tracks bubble-to-window associations for Cmd+Tab integration.
/// Real proxy windows were removed — macOS Mission Control doesn't reliably
/// display programmatically-miniaturized windows. Instead, the sidebar panel
/// itself serves as the Styx window in Cmd+Tab, with arrow-key navigation.
/// This class remains for headless test compatibility and future use.
@MainActor
final class ProxyWindowManager {
    private let store: BubbleStore
    private var headlessProxies: [String: String] = [:]  // id → title
    private let headless: Bool

    init(store: BubbleStore, headless: Bool = false) {
        self.store = store
        self.headless = headless
    }

    // MARK: - Lifecycle

    func refresh() {
        let docked = store.bubbles.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }
        let dockedIds = Set(docked.map(\.id))

        for id in headlessProxies.keys where !dockedIds.contains(id) {
            headlessProxies.removeValue(forKey: id)
        }
        for bubble in docked {
            headlessProxies[bubble.id] = bubble.name
        }

        StateLedger.shared.record(
            component: "ProxyWindowManager", operation: "refresh",
            before: [:],
            after: [
                "proxyCount": AnyCodable(headlessProxies.count),
                "headless": AnyCodable(headless),
            ]
        )
    }

    func closeAll() {
        headlessProxies.removeAll()
        StateLedger.shared.record(
            component: "ProxyWindowManager", operation: "closeAll",
            before: [:], after: ["proxyCount": AnyCodable(0)]
        )
    }

    // MARK: - Query

    func hasProxy(for bubbleId: String) -> Bool {
        headlessProxies[bubbleId] != nil
    }

    var proxyCount: Int {
        headlessProxies.count
    }

    func proxyTitle(for bubbleId: String) -> String? {
        headlessProxies[bubbleId]
    }
}
