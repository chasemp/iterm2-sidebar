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

            Button("Capture Current Terminal") {
                Task { await appDelegate.captureCurrentWindow() }
            }

            Divider()

            ForEach(appDelegate.store.bubbles) { bubble in
                Button(bubble.name) {
                    Task { await appDelegate.store.activateBubble(bubble) }
                }
            }

            if appDelegate.store.bubbles.isEmpty {
                Text("No bubbles").foregroundStyle(.secondary)
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
    let store = BubbleStore()
    private(set) lazy var sidebarController = SidebarPanelController(store: store, headless: headless)
    private(set) lazy var floatingManager = FloatingBubbleManager(store: store, headless: headless)
    private(set) lazy var proxyManager = ProxyWindowManager(store: store, headless: headless)
    var headless = false
    let hotkeyRegistrar = HotkeyRegistrar()
    private var dragStateMachine = BubbleDragStateMachine()
    private var focusTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var keyEventMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    var isPollingActive: Bool { pollTask != nil && !pollTask!.isCancelled }

    func toggleSidebar() {
        sidebarController.toggle()
    }

    func recallAll() {
        floatingManager.recallAll()
        sidebarController.refresh()
    }

    func handleDragUndock(bubbleId: String, screenPoint: CGPoint) {
        store.undockBubble(bubbleId, position: screenPoint)
        if let bubble = store.bubbles.first(where: { $0.id == bubbleId }) {
            floatingManager.showFloatingBubble(for: bubble)
        }
        sidebarController.refresh()
    }

    func handleRedockCheck(bubbleId: String, panelFrame: NSRect) {
        guard let sidebarFrame = sidebarController.panelFrame else { return }
        let dockZone = DockZone(sidebarFrame: sidebarFrame)
        let center = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
        if dockZone.contains(center) {
            let sortOrder = dockZone.insertionIndex(
                at: center,
                bubbleCount: store.bubbles.filter(\.docked).count
            )
            store.redockBubble(bubbleId, atSortOrder: sortOrder)
            floatingManager.hideFloatingBubble(for: bubbleId)
            sidebarController.refresh()
        }
    }

    /// Testable launch — accepts injected bridge.
    func launch(bridge: any BridgeService) async {
        await store.connectBridge(bridge)

        // Wire sidebar drag callbacks
        sidebarController.onDragChanged = { [weak self] id, translation in
            self?.dragStateMachine.dragChanged(bubbleId: id, translation: translation)
        }
        sidebarController.onDragEnded = { [weak self] id in
            guard let self else { return }
            guard let draggedId = self.dragStateMachine.dragEnded() else { return }
            let screenPoint = NSEvent.mouseLocation
            if let sidebarFrame = self.sidebarController.panelFrame {
                let dockZone = DockZone(sidebarFrame: sidebarFrame)
                if !dockZone.contains(screenPoint) {
                    self.handleDragUndock(bubbleId: draggedId, screenPoint: screenPoint)
                }
            }
        }

        if store.sidebarVisible {
            sidebarController.show()
        }

        // Wire redock callback
        floatingManager.onRedockCheck = { [weak self] id, frame in
            self?.handleRedockCheck(bubbleId: id, panelFrame: frame)
        }

        floatingManager.refresh()
        proxyManager.refresh()
        registerHotkeys()
        installKeyEventMonitor()
        installActivationObserver()
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
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
        proxyManager.closeAll()
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
            after: ["activationPolicy": AnyCodable("regular")]
        )

        NSApp.setActivationPolicy(.regular)
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
                    "bubbleCount": AnyCodable(self.store.bubbles.count),
                    "sidebarVisible": AnyCodable(self.store.sidebarVisible),
                    "bridgeConnected": AnyCodable(self.store.bridgeConnected),
                    "iTerm2Reachable": AnyCodable(self.store.iTerm2Reachable),
                    "focusedBubbleId": AnyCodable(self.store.focusedBubbleId ?? "none"),
                    "dockedCount": AnyCodable(self.store.bubbles.filter(\.docked).count),
                    "minCount": AnyCodable(self.store.bubbles.filter(\.collapsed).count),
                    "sidebarFrame": AnyCodable(self.sidebarController.panelFrame.map {
                        ["x": $0.origin.x, "y": $0.origin.y,
                         "width": $0.size.width, "height": $0.size.height]
                    } as Any? ?? "nil"),
                    "sidebarIsKeyWindow": AnyCodable(self.sidebarController.isKeyWindow),
                    "selectedBubbleIndex": AnyCodable(self.store.selectedBubbleIndex as Any),
                    "activationPolicy": AnyCodable("regular"),
                ]
            }

            StateLedger.shared.record(
                component: "Startup", operation: "launchComplete",
                before: [:],
                after: [
                    "bridgeConnected": AnyCodable(self.store.bridgeConnected),
                    "sidebarVisible": AnyCodable(self.store.sidebarVisible),
                    "bubbleCount": AnyCodable(self.store.bubbles.count),
                ]
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
        focusTask?.cancel()
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
        proxyManager.closeAll()
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

        // NOTE: Ctrl+Tab and Ctrl+Shift+Tab are NOT registered as global hotkeys
        // because they conflict with tab cycling in other apps (Chrome, etc.).
        // They are handled locally in installKeyEventMonitor() instead,
        // only when the sidebar is the key window.

        // Ctrl+1..9 for bubble by index
        for i in 1...9 {
            let combo = ParsedKeyCombo(
                keyString: "\(i)",
                modifiers: .control
            )
            let idx = i - 1
            hotkeyRegistrar.register(combo) { [weak self] in
                guard let self, let id = self.store.bubbleIdByIndex(idx),
                      let ws = self.store.bubbles.first(where: { $0.id == id }) else { return }
                Task { await self.store.activateBubble(ws) }
            }
        }
    }

    // MARK: - Keyboard Navigation

    /// Local NSEvent monitor for arrow keys and Fn+number when sidebar is key.
    /// Carbon RegisterEventHotKey does not support the Fn modifier, so we use
    /// a local event monitor instead (active only when Styx is frontmost).
    private func installKeyEventMonitor() {
        guard !headless else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.sidebarController.isKeyWindow else { return event }
            let handled = self.handleSidebarKeyEvent(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            )
            return handled ? nil : event
        }
        StateLedger.shared.record(
            component: "AppDelegate", operation: "installKeyEventMonitor",
            before: [:], after: ["installed": AnyCodable(true)]
        )
    }

    /// Observe app activation (Cmd+Tab to Styx) to focus the sidebar and
    /// enable keyboard navigation.
    private func installActivationObserver() {
        guard !headless else { return }
        StateLedger.shared.record(
            component: "AppDelegate", operation: "installActivationObserver",
            before: [:], after: ["installed": AnyCodable(true)]
        )
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.store.sidebarVisible else { return }
            self.sidebarController.makeKey()
            if self.store.selectedBubbleIndex == nil {
                self.store.selectNextBubble() // Select first bubble
            }
            StateLedger.shared.record(
                component: "AppDelegate", operation: "appActivated",
                before: [:],
                after: [
                    "sidebarFocused": AnyCodable(true),
                    "selectedBubbleIndex": AnyCodable(self.store.selectedBubbleIndex as Any),
                ]
            )
        }
    }

    // Key code → index maps for Fn+number and F-key navigation
    private static let fnNumberKeyCodes: [UInt16: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4,  // kVK_ANSI_1..5
        22: 5, 26: 6, 28: 7, 25: 8,          // kVK_ANSI_6..9
    ]

    private static let fKeyKeyCodes: [UInt16: Int] = [
        122: 0, 120: 1, 99: 2, 118: 3, 96: 4,  // F1..F5
        97: 5, 98: 6, 100: 7, 101: 8,           // F6..F9
    ]

    /// Handle a key event when the sidebar is focused.
    /// Returns true if the event was consumed.
    @discardableResult
    func handleSidebarKeyEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        let before: [String: AnyCodable] = [
            "keyCode": AnyCodable(keyCode),
            "hasFnModifier": AnyCodable(modifierFlags.contains(.function)),
            "selectedBubbleIndex": AnyCodable(store.selectedBubbleIndex as Any),
        ]

        var action = "unhandled"
        var handled = true

        // Tab key code = 48 (kVK_Tab)
        let isCtrlTab = keyCode == 48 && modifierFlags.contains(.control)
        let isCtrlShiftTab = isCtrlTab && modifierFlags.contains(.shift)

        switch keyCode {
        case 48 where isCtrlShiftTab: // Ctrl+Shift+Tab — previous bubble
            action = "ctrlShiftTab"
            store.selectPreviousBubble()
        case 48 where isCtrlTab: // Ctrl+Tab — next bubble
            action = "ctrlTab"
            store.selectNextBubble()
        case 125: // Down arrow
            action = "selectNext"
            store.selectNextBubble()
        case 126: // Up arrow
            action = "selectPrevious"
            store.selectPreviousBubble()
        case 36: // Return — activate selected
            action = "activateSelected"
            Task { await store.activateSelectedBubble() }
        case 53: // Escape — clear selection
            action = "clearSelection"
            store.clearBubbleSelection()
        default:
            // Fn + number key (function modifier + number key code)
            if modifierFlags.contains(.function),
               let index = Self.fnNumberKeyCodes[keyCode] {
                action = "fnNumber(\(index))"
                store.selectBubbleByIndex(index)
                Task { await store.activateSelectedBubble() }
            }
            // F-key (F1..F9)
            else if let index = Self.fKeyKeyCodes[keyCode] {
                action = "fKey(\(index))"
                store.selectBubbleByIndex(index)
                Task { await store.activateSelectedBubble() }
            } else {
                handled = false
            }
        }

        StateLedger.shared.record(
            component: "AppDelegate", operation: "handleSidebarKeyEvent",
            before: before,
            after: [
                "action": AnyCodable(action),
                "handled": AnyCodable(handled),
                "selectedBubbleIndex": AnyCodable(store.selectedBubbleIndex as Any),
            ]
        )
        return handled
    }
}
