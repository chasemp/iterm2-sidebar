import Foundation
import SwiftUI
import os

private let L = StateLedger.shared
private func A(_ v: Any) -> AnyCodable { AnyCodable(v) }

@Observable
@MainActor
final class WorkspaceStore {
    private let logger = Logger(subsystem: "com.styx", category: "WorkspaceStore")

    var config: StyxConfig = StyxConfig()

    var workspaces: [Workspace] {
        get { config.workspaces }
        set { config.workspaces = newValue }
    }

    var sidebarVisible: Bool {
        get { config.sidebar.visible }
        set { config.sidebar.visible = newValue }
    }

    var focusedWorkspaceId: String?
    var bridgeConnected = false
    var iTerm2Reachable = false

    // MARK: - Bubble State

    func bubbleState(for workspace: Workspace) -> BubbleState {
        if workspace.collapsed {
            return .minimized
        }
        if workspace.id == focusedWorkspaceId {
            return .focused
        }
        if workspace.itermWindowId != nil {
            return .active
        }
        return .dormant
    }

    // MARK: - Focus Tracking

    func handleFocusEvent(_ event: FocusEvent) {
        guard event.kind == .window, let windowId = event.windowId else { return }
        if let workspace = workspaces.first(where: { $0.itermWindowId == windowId }) {
            focusedWorkspaceId = workspace.id
        } else {
            focusedWorkspaceId = nil
        }
    }

    // MARK: - Window Liveness

    func refreshWindowLiveness(activeWindowIds: Set<String>) {
        workspaces.removeAll { workspace in
            if let windowId = workspace.itermWindowId, !activeWindowIds.contains(windowId) {
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
            L.record(component: "WorkspaceStore", operation: "pollWindowLiveness",
                     before: ["iTerm2Reachable": A(iTerm2Reachable)],
                     after: ["iTerm2Reachable": A(false)],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Rename

    func renameWorkspace(_ id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = trimmed
        saveConfig()
        if let windowId = workspaces[index].itermWindowId {
            Task {
                _ = try? await bridge?.call("set_window_title", args: ["window_id": windowId, "title": trimmed])
            }
        }
    }

    // MARK: - Dock / Undock

    func undockWorkspace(_ id: String, position: CGPoint) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].docked = false
        workspaces[index].floatingPosition = CodablePoint(position)
    }

    func redockWorkspace(_ id: String, atSortOrder sortOrder: Int) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].docked = true
        workspaces[index].floatingPosition = nil
        workspaces[index].sortOrder = sortOrder
    }

    func recallAll() {
        for i in workspaces.indices {
            workspaces[i].docked = true
            workspaces[i].floatingPosition = nil
        }
    }

    // MARK: - Minimize / Restore All

    func minimizeAll() async {
        let before: [String: AnyCodable] = [
            "workspaceCount": A(workspaces.count),
            "minimizedCount": A(workspaces.filter(\.collapsed).count)
        ]
        for workspace in workspaces {
            guard let asId = workspace.asWindowId, !workspace.collapsed else { continue }
            _ = try? await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": true])
        }
        for i in workspaces.indices { workspaces[i].collapsed = true }
        L.record(component: "WorkspaceStore", operation: "minimizeAll",
                 before: before,
                 after: ["minimizedCount": A(workspaces.filter(\.collapsed).count)])
    }

    func restoreAll() async {
        let before: [String: AnyCodable] = [
            "workspaceCount": A(workspaces.count),
            "minimizedCount": A(workspaces.filter(\.collapsed).count)
        ]
        for workspace in workspaces {
            guard let asId = workspace.asWindowId, workspace.collapsed else { continue }
            _ = try? await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": false])
        }
        for i in workspaces.indices { workspaces[i].collapsed = false }
        L.record(component: "WorkspaceStore", operation: "restoreAll",
                 before: before,
                 after: ["minimizedCount": A(workspaces.filter(\.collapsed).count)])
    }

    // MARK: - Cycling

    func nextWorkspaceId(forward: Bool) -> String? {
        let sorted = workspaces.sorted { $0.sortOrder < $1.sortOrder }
        guard !sorted.isEmpty else { return nil }
        let currentIndex = sorted.firstIndex { $0.id == focusedWorkspaceId } ?? -1
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % sorted.count
        } else {
            nextIndex = (currentIndex - 1 + sorted.count) % sorted.count
        }
        return sorted[nextIndex].id
    }

    func workspaceIdByIndex(_ index: Int) -> String? {
        let sorted = workspaces.sorted { $0.sortOrder < $1.sortOrder }
        guard index >= 0, index < sorted.count else { return nil }
        return sorted[index].id
    }

    // MARK: - Bridge-Dependent Actions (require iTerm2)

    private var bridge: (any BridgeService)?

    func start(bridge: any BridgeService) async {
        self.bridge = bridge
        loadConfig()
        let before: [String: AnyCodable] = ["bridgeConnected": A(false), "workspaceCount": A(workspaces.count)]
        do {
            try await bridge.start()
            bridgeConnected = true
            L.record(component: "WorkspaceStore", operation: "start",
                     before: before, after: ["bridgeConnected": A(true)])
        } catch {
            logger.error("Failed to start bridge: \(error)")
            bridgeConnected = false
            L.record(component: "WorkspaceStore", operation: "start",
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
            L.record(component: "WorkspaceStore", operation: "connectBridge",
                     before: before, after: ["bridgeConnected": A(true)])
        } catch {
            bridgeConnected = false
            L.record(component: "WorkspaceStore", operation: "connectBridge",
                     before: before, after: ["bridgeConnected": A(false)],
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func shutdown() async {
        await bridge?.stop()
        saveConfig()
    }

    func activateWorkspace(_ workspace: Workspace) async {
        guard let windowId = workspace.itermWindowId else { return }
        let before: [String: AnyCodable] = ["id": A(workspace.id), "windowId": A(windowId), "name": A(workspace.name)]
        do {
            _ = try await bridge?.call("activate_window", args: ["window_id": windowId])
            L.record(component: "WorkspaceStore", operation: "activateWorkspace",
                     before: before, after: ["activated": A(true)])
        } catch {
            logger.error("Failed to activate workspace \(workspace.name): \(error)")
            L.record(component: "WorkspaceStore", operation: "activateWorkspace",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func toggleMinimize(_ workspace: Workspace) async {
        guard let asId = workspace.asWindowId else {
            L.record(component: "WorkspaceStore", operation: "toggleMinimize",
                     before: ["id": A(workspace.id), "asWindowId": A("nil"), "collapsed": A(workspace.collapsed)],
                     after: ["id": A(workspace.id)],
                     outcome: .failure, errorMessage: "No AppleScript window ID")
            return
        }
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        let shouldMinimize = !workspace.collapsed
        let before: [String: AnyCodable] = [
            "id": A(workspace.id), "name": A(workspace.name),
            "asWindowId": A(asId), "collapsed": A(workspace.collapsed),
            "shouldMinimize": A(shouldMinimize)
        ]
        do {
            _ = try await bridge?.call("minimize_window", args: ["as_window_id": asId, "minimize": shouldMinimize])
            workspaces[index].collapsed = shouldMinimize
            L.record(component: "WorkspaceStore", operation: "toggleMinimize",
                     before: before,
                     after: ["collapsed": A(shouldMinimize), "bridgeCallSucceeded": A(true)])
        } catch {
            logger.error("Failed to toggle minimize \(workspace.name): \(error)")
            L.record(component: "WorkspaceStore", operation: "toggleMinimize",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func createWorkspace(name: String, color: String, icon: String, tabs: [WorkspaceTab]) async {
        let tabArgs = tabs.map { tab -> [String: Any] in
            var dict: [String: Any] = ["name": tab.name]
            if let dir = tab.dir { dict["dir"] = dir }
            if let cmd = tab.cmd { dict["cmd"] = cmd }
            return dict
        }

        let before: [String: AnyCodable] = [
            "name": A(name), "workspaceCount": A(workspaces.count),
            "bridgeConnected": A(bridgeConnected)
        ]

        do {
            let result = try await bridge?.call("create_window", args: ["tabs": tabArgs])
            guard let data = result as? [String: Any],
                  let windowId = data["window_id"] as? String else {
                L.record(component: "WorkspaceStore", operation: "createWorkspace",
                         before: before, after: before,
                         outcome: .failure, errorMessage: "No window_id in bridge response")
                return
            }

            _ = try? await bridge?.call("set_window_title", args: ["window_id": windowId, "title": name])

            let asId = (data["as_window_id"] as? Int)
            let workspace = Workspace(
                name: name, color: color, icon: icon,
                sortOrder: workspaces.count,
                itermWindowId: windowId, asWindowId: asId, tabs: tabs
            )
            workspaces.append(workspace)
            saveConfig()
            L.record(component: "WorkspaceStore", operation: "createWorkspace",
                     before: before,
                     after: ["workspaceCount": A(workspaces.count), "windowId": A(windowId), "asWindowId": A(asId as Any)])
        } catch {
            logger.error("Failed to create workspace: \(error)")
            L.record(component: "WorkspaceStore", operation: "createWorkspace",
                     before: before, after: before,
                     outcome: .failure, errorMessage: error.localizedDescription)
        }
    }

    func deleteWorkspace(_ workspace: Workspace) async {
        if let windowId = workspace.itermWindowId {
            _ = try? await bridge?.call("close_window", args: ["window_id": windowId])
        }
        workspaces.removeAll { $0.id == workspace.id }
        saveConfig()
    }

    // MARK: - Capture Current Window

    func captureCurrentWindow(name: String? = nil, color: String, icon: String) async {
        do {
            let result = try await bridge?.call("get_active_window", args: [:])
            guard let data = result as? [String: Any],
                  let windowId = data["window_id"] as? String else { return }

            let tabsData = data["tabs"] as? [[String: Any]] ?? []
            let tabs = tabsData.compactMap { tabDict -> WorkspaceTab? in
                let sessions = tabDict["sessions"] as? [[String: Any]] ?? []
                let sessionName = sessions.first?["name"] as? String ?? "shell"
                return WorkspaceTab(name: sessionName, dir: nil, cmd: nil)
            }

            let resolvedName = name ?? tabs.first?.name ?? "Workspace"

            let workspace = Workspace(
                name: resolvedName, color: color, icon: icon,
                sortOrder: workspaces.count,
                itermWindowId: windowId, tabs: tabs
            )
            workspaces.append(workspace)
            saveConfig()
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
            L.record(component: "WorkspaceStore", operation: "saveConfig",
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
            L.record(component: "WorkspaceStore", operation: "loadConfig",
                     before: ["path": A(target.path)],
                     after: ["workspaceCount": A(workspaces.count), "sidebarVisible": A(sidebarVisible)])
        } catch {
            logger.error("Failed to load config: \(error)")
            L.record(component: "WorkspaceStore", operation: "loadConfig",
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
