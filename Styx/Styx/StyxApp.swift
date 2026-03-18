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

    var body: some View {
        VStack {
            Button(appDelegate.store.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                appDelegate.toggleSidebar()
            }

            Button("Recall All Bubbles") {
                appDelegate.recallAll()
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
                Text(appDelegate.store.bridgeConnected ? "Connected" : "Disconnected")
                    .font(.caption)
            }

            Divider()
            SettingsLink { Text("Settings...") }
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
    lazy var sidebarController = SidebarPanelController(store: store)
    lazy var floatingManager = FloatingBubbleManager(store: store)
    let hotkeyRegistrar = HotkeyRegistrar()
    private var focusTask: Task<Void, Never>?

    func toggleSidebar() {
        sidebarController.toggle()
    }

    func recallAll() {
        floatingManager.recallAll()
        sidebarController.refresh()
    }

    /// Testable launch — accepts injected bridge.
    func launch(bridge: any BridgeService) async {
        await store.connectBridge(bridge)

        if store.sidebarVisible {
            sidebarController.show()
        }

        floatingManager.refresh()
        registerHotkeys()

        // Subscribe to focus events if bridge supports it
        if let iterm2Bridge = bridge as? ITerm2Bridge {
            focusTask = Task { [weak self] in
                for await event in iterm2Bridge.focusEvents {
                    await MainActor.run { self?.store.handleFocusEvent(event) }
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            let bridge = ITerm2Bridge()
            await launch(bridge: bridge)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusTask?.cancel()
        floatingManager.savePositions()
        store.saveConfig()
    }

    // MARK: - Hotkey Registration

    private func registerHotkeys() {
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
