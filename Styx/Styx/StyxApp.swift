import SwiftUI
import AppKit
import Carbon

@main
struct StyxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Styx", systemImage: "square.grid.3x3.topleft.filled") {
            MenuBarContent(appDelegate: appDelegate)
        }

        Settings {
            SettingsView(store: appDelegate.store)
        }
    }
}

// MARK: - MenuBar Content

struct MenuBarContent: View {
    let appDelegate: AppDelegate

    private var bridgeStatusText: String {
        if !appDelegate.store.bridgeConnected { return "Bridge disconnected" }
        if !appDelegate.store.iTerm2Reachable { return "iTerm2 not responding" }
        return "Connected"
    }

    var body: some View {
        VStack {
            Button(appDelegate.store.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                appDelegate.toggleSidebar()
            }

            Button("Recall All Bubbles") {
                appDelegate.recallAll()
            }

            Button("Capture Current Window") {
                Task { await appDelegate.captureCurrentWindow() }
            }

            Divider()

            ForEach(appDelegate.store.workspaces) { workspace in
                Button(workspace.name) {
                    Task { await appDelegate.store.activateWorkspace(workspace) }
                }
            }

            if appDelegate.store.workspaces.isEmpty {
                Text("No workspaces").foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Circle()
                    .fill(appDelegate.store.bridgeConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(bridgeStatusText)
                    .font(.caption)
            }

            Divider()
            SettingsLink { Text("Settings...") }
            Text("Styx v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Quit Styx") {
                Task {
                    await appDelegate.store.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WorkspaceStore()
    private(set) lazy var sidebarController = SidebarPanelController(store: store, headless: headless)
    private(set) lazy var floatingManager = FloatingBubbleManager(store: store, headless: headless)
    var headless = false
    let hotkeyRegistrar = HotkeyRegistrar()
    private var dragStateMachine = BubbleDragStateMachine()
    private var focusTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    var isPollingActive: Bool { pollTask != nil && !pollTask!.isCancelled }

    func toggleSidebar() {
        sidebarController.toggle()
    }

    func recallAll() {
        floatingManager.recallAll()
        sidebarController.refresh()
    }

    func handleDragUndock(workspaceId: String, screenPoint: CGPoint) {
        store.undockWorkspace(workspaceId, position: screenPoint)
        if let workspace = store.workspaces.first(where: { $0.id == workspaceId }) {
            floatingManager.showFloatingBubble(for: workspace)
        }
        sidebarController.refresh()
    }

    func handleRedockCheck(workspaceId: String, panelFrame: NSRect) {
        guard let sidebarFrame = sidebarController.panelFrame else { return }
        let dockZone = DockZone(sidebarFrame: sidebarFrame)
        let center = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
        if dockZone.contains(center) {
            let sortOrder = dockZone.insertionIndex(
                at: center,
                bubbleCount: store.workspaces.filter(\.docked).count
            )
            store.redockWorkspace(workspaceId, atSortOrder: sortOrder)
            floatingManager.hideFloatingBubble(for: workspaceId)
            sidebarController.refresh()
        }
    }

    /// Testable launch — accepts injected bridge.
    func launch(bridge: any BridgeService) async {
        await store.connectBridge(bridge)

        // Wire sidebar drag callbacks
        sidebarController.onDragChanged = { [weak self] id, translation in
            self?.dragStateMachine.dragChanged(workspaceId: id, translation: translation)
        }
        sidebarController.onDragEnded = { [weak self] id in
            guard let self else { return }
            guard let draggedId = self.dragStateMachine.dragEnded() else { return }
            let screenPoint = NSEvent.mouseLocation
            if let sidebarFrame = self.sidebarController.panelFrame {
                let dockZone = DockZone(sidebarFrame: sidebarFrame)
                if !dockZone.contains(screenPoint) {
                    self.handleDragUndock(workspaceId: draggedId, screenPoint: screenPoint)
                }
            }
        }

        if store.sidebarVisible {
            sidebarController.show()
        }

        // Wire redock callback
        floatingManager.onRedockCheck = { [weak self] id, frame in
            self?.handleRedockCheck(workspaceId: id, panelFrame: frame)
        }

        floatingManager.refresh()
        registerHotkeys()
        startPolling()

        // Subscribe to focus events if bridge supports it
        if let iterm2Bridge = bridge as? ITerm2Bridge {
            focusTask = Task { [weak self] in
                for await event in iterm2Bridge.focusEvents {
                    await MainActor.run { self?.store.handleFocusEvent(event) }
                }
            }
        }
    }

    func shutdownForTest() async {
        pollTask?.cancel()
        pollTask = nil
        focusTask?.cancel()
        focusTask = nil
        await store.shutdown()
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self else { break }
                await self.store.pollWindowLiveness()
            }
        }
    }

    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        StateLedger.shared.record(
            component: "Startup", operation: "applicationDidFinishLaunching",
            before: ["isRunningTests": AnyCodable(false)],
            after: ["activationPolicy": AnyCodable("accessory")]
        )

        NSApp.setActivationPolicy(.accessory)
        AccessibilityChecker.promptIfNeeded()

        Task { @MainActor in
            let bridge = ITerm2Bridge()
            store.loadConfig()
            await launch(bridge: bridge)

            // Wire current state provider for ledger dumps
            StateLedger.shared.currentStateProvider = { [weak self] in
                guard let self else { return [:] }
                return [
                    "buildVersion": AnyCodable(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"),
                    "appVersion": AnyCodable(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"),
                    "workspaceCount": AnyCodable(self.store.workspaces.count),
                    "sidebarVisible": AnyCodable(self.store.sidebarVisible),
                    "bridgeConnected": AnyCodable(self.store.bridgeConnected),
                    "iTerm2Reachable": AnyCodable(self.store.iTerm2Reachable),
                    "focusedWorkspaceId": AnyCodable(self.store.focusedWorkspaceId ?? "none"),
                    "dockedCount": AnyCodable(self.store.workspaces.filter(\.docked).count),
                    "minimizedCount": AnyCodable(self.store.workspaces.filter(\.collapsed).count),
                    "sidebarFrame": AnyCodable(self.sidebarController.panelFrame.map {
                        ["x": $0.origin.x, "y": $0.origin.y,
                         "width": $0.size.width, "height": $0.size.height]
                    } as Any? ?? "nil"),
                ]
            }

            StateLedger.shared.record(
                component: "Startup", operation: "launchComplete",
                before: [:],
                after: [
                    "bridgeConnected": AnyCodable(self.store.bridgeConnected),
                    "sidebarVisible": AnyCodable(self.store.sidebarVisible),
                    "workspaceCount": AnyCodable(self.store.workspaces.count),
                ]
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
        focusTask?.cancel()
        floatingManager.savePositions()
        store.saveConfig()
    }

    // MARK: - Hotkey Registration

    func captureCurrentWindow() async {
        await store.captureCurrentWindow(color: "#4A90D9", icon: "terminal")
        sidebarController.refresh()
    }

    func reregisterHotkeys() {
        hotkeyRegistrar.unregisterAll()
        registerHotkeys()
    }

    func registerHotkeys() {
        if let combo = HotkeyParser.parse(store.config.hotkeys.toggleSidebar) {
            hotkeyRegistrar.register(combo) { [weak self] in self?.toggleSidebar() }
        }

        if let combo = HotkeyParser.parse(store.config.hotkeys.nextWorkspace) {
            hotkeyRegistrar.register(combo) { [weak self] in
                guard let self, let id = self.store.nextWorkspaceId(forward: true),
                      let ws = self.store.workspaces.first(where: { $0.id == id }) else { return }
                Task { await self.store.activateWorkspace(ws) }
            }
        }

        if let combo = HotkeyParser.parse(store.config.hotkeys.prevWorkspace) {
            hotkeyRegistrar.register(combo) { [weak self] in
                guard let self, let id = self.store.nextWorkspaceId(forward: false),
                      let ws = self.store.workspaces.first(where: { $0.id == id }) else { return }
                Task { await self.store.activateWorkspace(ws) }
            }
        }

        // Ctrl+1..9 for workspace by index
        for i in 1...9 {
            let combo = ParsedKeyCombo(
                keyString: "\(i)",
                modifiers: .control
            )
            let idx = i - 1
            hotkeyRegistrar.register(combo) { [weak self] in
                guard let self, let id = self.store.workspaceIdByIndex(idx),
                      let ws = self.store.workspaces.first(where: { $0.id == id }) else { return }
                Task { await self.store.activateWorkspace(ws) }
            }
        }
    }
}
