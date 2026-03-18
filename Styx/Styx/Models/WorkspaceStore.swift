import Foundation
import SwiftUI
import os

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

    // MARK: - Bubble State

    func bubbleState(for workspace: Workspace) -> BubbleState {
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
        do {
            try await bridge.start()
            bridgeConnected = true
        } catch {
            logger.error("Failed to start bridge: \(error)")
            bridgeConnected = false
        }
    }

    /// Connect a bridge without loading config from disk. Used for testing.
    func connectBridge(_ bridge: any BridgeService) async {
        self.bridge = bridge
        do {
            try await bridge.start()
            bridgeConnected = true
        } catch {
            bridgeConnected = false
        }
    }

    func shutdown() async {
        await bridge?.stop()
        saveConfig()
    }

    func activateWorkspace(_ workspace: Workspace) async {
        guard let windowId = workspace.itermWindowId else { return }
        do {
            _ = try await bridge?.call("activate_window", args: ["window_id": windowId])
        } catch {
            logger.error("Failed to activate workspace \(workspace.name): \(error)")
        }
    }

    func createWorkspace(name: String, color: String, icon: String, tabs: [WorkspaceTab]) async {
        let tabArgs = tabs.map { tab -> [String: Any] in
            var dict: [String: Any] = ["name": tab.name]
            if let dir = tab.dir { dict["dir"] = dir }
            if let cmd = tab.cmd { dict["cmd"] = cmd }
            return dict
        }

        do {
            let result = try await bridge?.call("create_window", args: ["tabs": tabArgs])
            guard let data = result as? [String: Any],
                  let windowId = data["window_id"] as? String else { return }

            let workspace = Workspace(
                name: name, color: color, icon: icon,
                sortOrder: workspaces.count,
                itermWindowId: windowId, tabs: tabs
            )
            workspaces.append(workspace)
            saveConfig()
        } catch {
            logger.error("Failed to create workspace: \(error)")
        }
    }

    func deleteWorkspace(_ workspace: Workspace) async {
        if let windowId = workspace.itermWindowId {
            _ = try? await bridge?.call("close_window", args: ["window_id": windowId])
        }
        workspaces.removeAll { $0.id == workspace.id }
        saveConfig()
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
        } catch {
            logger.error("Failed to load config: \(error)")
        }
    }

    static var defaultConfigURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Styx", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspaces.json")
    }
}
