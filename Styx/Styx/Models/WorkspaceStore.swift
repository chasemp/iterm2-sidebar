import Foundation
import SwiftUI
import os

private let L = StateLedger.shared
private func A(_ v: Any) -> AnyCodable { AnyCodable(v) }

@Observable
@MainActor
final class BubbleStore {
    private let logger = Logger(subsystem: "com.styx", category: "BubbleStore")

    var config: StyxConfig = StyxConfig()

    var bubbles: [Bubble] {
        get { config.bubbles }
        set { config.bubbles = newValue }
    }

    var sidebarVisible: Bool {
        get { config.sidebar.visible }
        set { config.sidebar.visible = newValue }
    }

    var focusedBubbleId: String?
    var selectedBubbleIndex: Int?
    var bridgeConnected = false
    var iTerm2Reachable = false

    // MARK: - Bubble State

    func bubbleState(for bubble: Bubble) -> BubbleState {
        if bubble.collapsed {
            return .min
        }
        if bubble.id == focusedBubbleId {
            return .focused
        }
        if bubble.itermWindowId != nil {
            return .active
        }
        return .dormant
    }

    // MARK: - Focus Tracking

    func handleFocusEvent(_ event: FocusEvent) {
        guard event.kind == .window, let windowId = event.windowId else { return }
        if let bubble = bubbles.first(where: { $0.itermWindowId == windowId }) {
            focusedBubbleId = bubble.id
        } else {
            focusedBubbleId = nil
        }
    }

    // MARK: - Window Liveness

    func refreshWindowLiveness(activeWindowIds: Set<String>) {
        bubbles.removeAll { bubble in
            if let windowId = bubble.itermWindowId, !activeWindowIds.contains(windowId) {
                return true
            }
            return false
        }
        saveConfig()
    }

    // MARK: - Window Polling

    func pollWindowLiveness() async {
        do {
            let result = try await bridge?.call("list_windows", args: [:])
            guard let windows = result as? [[String: Any]] else { return }
            let activeIds = Set(windows.compactMap { $0["window_id"] as? String })
            refreshWindowLiveness(activeWindowIds: activeIds)
            iTerm2Reachable = true
        } catch {
            iTerm2Reachable = false
            L.record(component: "BubbleStore", operation: "pollWindowLiveness",
                     before: ["iTerm2Reachable": A(iTerm2Reachable)],
                     after: ["iTerm2Reachable": A(false)],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Rename

    func renameBubble(_ id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].name = trimmed
        saveConfig()
        let b = bubbles[index]
        Task { await applyBubbleDecoration(b) }
    }

    // MARK: - Dock / Undock

    func undockBubble(_ id: String, position: CGPoint) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].docked = false
        bubbles[index].floatingPosition = CodablePoint(position)
    }

    func redockBubble(_ id: String, atSortOrder sortOrder: Int) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].docked = true
        bubbles[index].floatingPosition = nil
        bubbles[index].sortOrder = sortOrder
    }

    func recallAll() {
        for i in bubbles.indices {
            bubbles[i].docked = true
            bubbles[i].floatingPosition = nil
        }
    }

    // MARK: - Min / Restore All

    func minAll() async {
        let before: [String: AnyCodable] = [
            "bubbleCount": A(bubbles.count),
            "minCount": A(bubbles.filter(\.collapsed).count)
        ]
        for bubble in bubbles {
            guard let asId = bubble.asWindowId, !bubble.collapsed else { continue }
            _ = try? await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": true])
        }
        for i in bubbles.indices { bubbles[i].collapsed = true }
        L.record(component: "BubbleStore", operation: "minAll",
                 before: before,
                 after: ["minCount": A(bubbles.filter(\.collapsed).count)])
    }

    func restoreAll() async {
        let before: [String: AnyCodable] = [
            "bubbleCount": A(bubbles.count),
            "minCount": A(bubbles.filter(\.collapsed).count)
        ]
        for bubble in bubbles {
            guard let asId = bubble.asWindowId, bubble.collapsed else { continue }
            _ = try? await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": false])
        }
        for i in bubbles.indices { bubbles[i].collapsed = false }
        L.record(component: "BubbleStore", operation: "restoreAll",
                 before: before,
                 after: ["minCount": A(bubbles.filter(\.collapsed).count)])
    }

    // MARK: - Cycling

    func nextBubbleId(forward: Bool) -> String? {
        let sorted = bubbles.sorted { $0.sortOrder < $1.sortOrder }
        guard !sorted.isEmpty else { return nil }
        let currentIndex = sorted.firstIndex { $0.id == focusedBubbleId } ?? -1
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % sorted.count
        } else {
            nextIndex = (currentIndex - 1 + sorted.count) % sorted.count
        }
        return sorted[nextIndex].id
    }

    func bubbleIdByIndex(_ index: Int) -> String? {
        let sorted = bubbles.sorted { $0.sortOrder < $1.sortOrder }
        guard index >= 0, index < sorted.count else { return nil }
        return sorted[index].id
    }

    // MARK: - Bubble Selection (Keyboard Navigation)

    private var dockedSorted: [Bubble] {
        bubbles.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }
    }

    func selectNextBubble() {
        let docked = dockedSorted
        guard !docked.isEmpty else { return }
        if let current = selectedBubbleIndex {
            selectedBubbleIndex = (current + 1) % docked.count
        } else {
            selectedBubbleIndex = 0
        }
        L.record(component: "BubbleStore", operation: "selectNextBubble",
                 before: [:], after: ["selectedBubbleIndex": A(selectedBubbleIndex as Any)])
    }

    func selectPreviousBubble() {
        let docked = dockedSorted
        guard !docked.isEmpty else { return }
        if let current = selectedBubbleIndex {
            selectedBubbleIndex = (current - 1 + docked.count) % docked.count
        } else {
            selectedBubbleIndex = docked.count - 1
        }
        L.record(component: "BubbleStore", operation: "selectPreviousBubble",
                 before: [:], after: ["selectedBubbleIndex": A(selectedBubbleIndex as Any)])
    }

    func selectBubbleByIndex(_ index: Int) {
        let docked = dockedSorted
        guard index >= 0, index < docked.count else { return }
        selectedBubbleIndex = index
        L.record(component: "BubbleStore", operation: "selectBubbleByIndex",
                 before: [:], after: ["selectedBubbleIndex": A(index)])
    }

    func activateSelectedBubble() async {
        let docked = dockedSorted
        guard let index = selectedBubbleIndex, index < docked.count else {
            L.record(component: "BubbleStore", operation: "activateSelectedBubble",
                     before: ["selectedBubbleIndex": A(selectedBubbleIndex as Any)],
                     after: [:], outcome: .failure, errorMessage: "No valid selection")
            return
        }
        let b = docked[index]
        L.record(component: "BubbleStore", operation: "activateSelectedBubble",
                 before: ["selectedBubbleIndex": A(index), "bubbleId": A(b.id), "name": A(b.name)],
                 after: ["activating": A(true)])
        await activateBubble(b)
    }

    func clearBubbleSelection() {
        selectedBubbleIndex = nil
        L.record(component: "BubbleStore", operation: "clearBubbleSelection",
                 before: [:], after: ["selectedBubbleIndex": A("nil")])
    }

    // MARK: - Bridge-Dependent Actions (require iTerm2)

    private var bridge: (any BridgeService)?

    func start(bridge: any BridgeService) async {
        self.bridge = bridge
        loadConfig()
        let before: [String: AnyCodable] = ["bridgeConnected": A(false), "bubbleCount": A(bubbles.count)]
        do {
            try await bridge.start()
            bridgeConnected = true
            L.record(component: "BubbleStore", operation: "start",
                     before: before, after: ["bridgeConnected": A(true)])
        } catch {
            logger.error("Failed to start bridge: \(error)")
            bridgeConnected = false
            L.record(component: "BubbleStore", operation: "start",
                     before: before, after: ["bridgeConnected": A(false)],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func connectBridge(_ bridge: any BridgeService) async {
        self.bridge = bridge
        let before: [String: AnyCodable] = ["bridgeConnected": A(false)]
        do {
            try await bridge.start()
            bridgeConnected = true
            L.record(component: "BubbleStore", operation: "connectBridge",
                     before: before, after: ["bridgeConnected": A(true)])
        } catch {
            bridgeConnected = false
            L.record(component: "BubbleStore", operation: "connectBridge",
                     before: before, after: ["bridgeConnected": A(false)],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func shutdown() async {
        await bridge?.stop()
        saveConfig()
    }

    func activateBubble(_ bubble: Bubble) async {
        guard let windowId = bubble.itermWindowId else { return }
        let before: [String: AnyCodable] = ["id": A(bubble.id), "windowId": A(windowId), "name": A(bubble.name)]
        do {
            _ = try await bridge?.call("activate_window", args: ["window_id": windowId])
            L.record(component: "BubbleStore", operation: "activateBubble",
                     before: before, after: ["activated": A(true)])
        } catch {
            logger.error("Failed to activate bubble \(bubble.name): \(error)")
            L.record(component: "BubbleStore", operation: "activateBubble",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func toggleMin(_ bubble: Bubble) async {
        guard let asId = bubble.asWindowId else {
            L.record(component: "BubbleStore", operation: "toggleMin",
                     before: ["id": A(bubble.id), "asWindowId": A("nil"), "collapsed": A(bubble.collapsed)],
                     after: ["id": A(bubble.id)],
                     outcome: .failure, errorMessage: "No AppleScript window ID")
            return
        }
        guard let index = bubbles.firstIndex(where: { $0.id == bubble.id }) else { return }
        let shouldMin = !bubble.collapsed
        let before: [String: AnyCodable] = [
            "id": A(bubble.id), "name": A(bubble.name),
            "asWindowId": A(asId), "collapsed": A(bubble.collapsed),
            "shouldMin": A(shouldMin)
        ]
        do {
            _ = try await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": shouldMin])
            bubbles[index].collapsed = shouldMin
            L.record(component: "BubbleStore", operation: "toggleMin",
                     before: before,
                     after: ["collapsed": A(shouldMin), "bridgeCallSucceeded": A(true)])
        } catch {
            logger.error("Failed to toggle min \(bubble.name): \(error)")
            L.record(component: "BubbleStore", operation: "toggleMin",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func createBubble(name: String, color: String, icon: String, tabs: [BubbleTab]) async {
        let tabArgs = tabs.map { tab -> [String: Any] in
            var dict: [String: Any] = ["name": tab.name]
            if let dir = tab.dir { dict["dir"] = dir }
            if let cmd = tab.cmd { dict["cmd"] = cmd }
            return dict
        }

        let before: [String: AnyCodable] = [
            "name": A(name), "bubbleCount": A(bubbles.count),
            "bridgeConnected": A(bridgeConnected)
        ]

        do {
            let result = try await bridge?.call("create_window", args: ["tabs": tabArgs])
            guard let data = result as? [String: Any],
                  let windowId = data["window_id"] as? String else {
                L.record(component: "BubbleStore", operation: "createBubble",
                         before: before, after: before,
                         outcome: .failure, errorMessage: "No window_id in bridge response")
                return
            }

            let asId = (data["as_window_id"] as? Int)
            let bubble = Bubble(
                name: name, color: color, icon: icon,
                sortOrder: bubbles.count,
                itermWindowId: windowId, asWindowId: asId, tabs: tabs
            )
            bubbles.append(bubble)
            saveConfig()
            L.record(component: "BubbleStore", operation: "createBubble",
                     before: before,
                     after: ["bubbleCount": A(bubbles.count), "windowId": A(windowId), "asWindowId": A(asId as Any)])

            // Apply bubble decoration after bubble is saved
            await applyBubbleDecoration(bubble)
        } catch {
            logger.error("Failed to create bubble: \(error)")
            L.record(component: "BubbleStore", operation: "createBubble",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func deleteBubble(_ bubble: Bubble) async {
        if let windowId = bubble.itermWindowId {
            _ = try? await bridge?.call("close_window", args: ["window_id": windowId])
        }
        bubbles.removeAll { $0.id == bubble.id }
        saveConfig()
    }

    // MARK: - Bubble Decoration on iTerm2 Windows

    /// Apply bubble name and color to the iTerm2 window so the user can
    /// visually identify which bubble owns which window.
    func applyBubbleDecoration(_ bubble: Bubble) async {
        guard let windowId = bubble.itermWindowId else {
            L.record(component: "BubbleStore", operation: "applyBubbleDecoration",
                     before: ["id": A(bubble.id), "windowId": A("nil")],
                     after: [:], outcome: .failure, errorMessage: "No iTerm2 window ID")
            return
        }
        let before: [String: AnyCodable] = [
            "id": A(bubble.id), "name": A(bubble.name),
            "color": A(bubble.color), "windowId": A(windowId),
            "showBadge": A(config.terminal.showBubbleBadge),
            "setEnvVar": A(config.terminal.setBubbleEnvVar),
        ]
        var titleOk = false
        var colorOk = false
        var envOk = false
        do {
            _ = try await bridge?.call("set_window_title", args: ["window_id": windowId, "title": bubble.name])
            titleOk = true
        } catch {
            logger.error("applyBubbleDecoration: set_window_title failed: \(error)")
        }
        do {
            _ = try await bridge?.call("set_tab_color", args: [
                "window_id": windowId,
                "hex_color": bubble.color,
                "badge_text": config.terminal.showBubbleBadge ? bubble.name : "",
            ])
            colorOk = true
        } catch {
            logger.error("applyBubbleDecoration: set_tab_color failed: \(error)")
        }
        if config.terminal.setBubbleEnvVar {
            do {
                _ = try await bridge?.call("set_bubble_env", args: [
                    "window_id": windowId,
                    "bubble_name": bubble.name,
                    "hex_color": bubble.color,
                ])
                envOk = true
            } catch {
                logger.error("applyBubbleDecoration: set_bubble_env failed: \(error)")
            }
        }
        L.record(component: "BubbleStore", operation: "applyBubbleDecoration",
                 before: before,
                 after: ["titleApplied": A(titleOk), "colorApplied": A(colorOk), "envApplied": A(envOk)],
                 outcome: (titleOk && colorOk) ? .success : .failure,
                 errorMessage: (!titleOk || !colorOk) ? "Partial failure: title=\(titleOk) color=\(colorOk) env=\(envOk)" : nil)
    }

    // MARK: - Capture Current Window

    func captureCurrentWindow(name: String? = nil, color: String, icon: String) async {
        do {
            let result = try await bridge?.call("get_active_window", args: [:])
            guard let data = result as? [String: Any],
                  let windowId = data["window_id"] as? String else { return }

            let tabsData = data["tabs"] as? [[String: Any]] ?? []
            let tabs = tabsData.compactMap { tabDict -> BubbleTab? in
                let sessions = tabDict["sessions"] as? [[String: Any]] ?? []
                let sessionName = sessions.first?["name"] as? String ?? "shell"
                return BubbleTab(name: sessionName, dir: nil, cmd: nil)
            }

            let resolvedName = name ?? tabs.first?.name ?? "Bubble"

            let bubble = Bubble(
                name: resolvedName, color: color, icon: icon,
                sortOrder: bubbles.count,
                itermWindowId: windowId, tabs: tabs
            )
            bubbles.append(bubble)
            saveConfig()

            // Apply bubble decoration after bubble is saved
            await applyBubbleDecoration(bubble)
        } catch {
            logger.error("Failed to capture current window: \(error)")
        }
    }

    // MARK: - Persistence

    func saveConfig(to url: URL? = nil) {
        let target = url ?? Self.defaultConfigURL
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: target, options: .atomic)
        } catch {
            logger.error("Failed to save config: \(error)")
            L.record(component: "BubbleStore", operation: "saveConfig",
                     before: [:], after: [:],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func loadConfig(from url: URL? = nil) {
        let target = url ?? Self.defaultConfigURL
        guard FileManager.default.fileExists(atPath: target.path) else {
            logger.info("No config file found, using defaults")
            return
        }
        do {
            let data = try Data(contentsOf: target)
            config = try JSONDecoder().decode(StyxConfig.self, from: data)
            L.record(component: "BubbleStore", operation: "loadConfig",
                     before: ["path": A(target.path)],
                     after: ["bubbleCount": A(bubbles.count), "sidebarVisible": A(sidebarVisible)])
        } catch {
            logger.error("Failed to load config: \(error)")
            L.record(component: "BubbleStore", operation: "loadConfig",
                     before: ["path": A(target.path)], after: [:],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    static var defaultConfigURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Styx", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspaces.json")
    }
}
