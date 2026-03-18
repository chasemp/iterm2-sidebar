import AppKit
import SwiftUI

final class FloatingBubblePanel: NSPanel {
    let workspaceId: String
    var onMouseUp: ((String, NSRect) -> Void)?

    init(workspaceId: String, position: CGPoint, contentView: NSView? = nil) {
        self.workspaceId = workspaceId
        super.init(
            contentRect: NSRect(x: position.x, y: position.y, width: 72, height: 80),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true

        if let contentView {
            self.contentView = contentView
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?(workspaceId, frame)
    }

    func clampToScreen() {
        guard let screen = NSScreen.main else { return }
        var f = frame
        f.origin.x = max(0, min(f.origin.x, screen.frame.width - f.width))
        f.origin.y = max(0, min(f.origin.y, screen.frame.height - f.height))
        setFrame(f, display: true)
    }

    var currentPosition: CGPoint { frame.origin }
}

@MainActor
final class FloatingBubbleManager {
    private var panels: [String: FloatingBubblePanel] = [:]
    private let store: WorkspaceStore

    var onRedockCheck: ((String, NSRect) -> Void)?
    private let headless: Bool

    init(store: WorkspaceStore, headless: Bool = false) {
        self.store = store
        self.headless = headless
    }

    func showFloatingBubble(for workspace: Workspace) {
        guard panels[workspace.id] == nil else { return }
        let position = workspace.floatingPosition?.cgPoint ?? CGPoint(x: 100, y: 100)

        // Create bubble content
        let bubbleView = BubbleView(
            workspace: workspace,
            state: store.bubbleState(for: workspace),
            onTap: { [weak self] in
                Task { await self?.store.activateWorkspace(workspace) }
            }
        )
        let hostingView = NSHostingView(rootView: bubbleView)

        let panel = FloatingBubblePanel(
            workspaceId: workspace.id,
            position: position,
            contentView: hostingView
        )
        panel.onMouseUp = { [weak self] id, frame in
            self?.onRedockCheck?(id, frame)
        }
        if !headless {
            panel.orderFront(nil)
            panel.clampToScreen()
        }
        panels[workspace.id] = panel
    }

    func hideFloatingBubble(for workspaceId: String) {
        if !headless { panels[workspaceId]?.orderOut(nil) }
        panels.removeValue(forKey: workspaceId)
    }

    func recallAll() {
        for id in panels.keys {
            store.redockWorkspace(id, atSortOrder: store.workspaces.filter(\.docked).count)
            if !headless { panels[id]?.orderOut(nil) }
        }
        panels.removeAll()
    }

    func refresh() {
        let undocked = store.workspaces.filter { !$0.docked }
        let undockedIds = Set(undocked.map(\.id))

        for id in panels.keys where !undockedIds.contains(id) {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
        }
        for workspace in undocked where panels[workspace.id] == nil {
            showFloatingBubble(for: workspace)
        }
    }

    func savePositions() {
        for (id, panel) in panels {
            store.undockWorkspace(id, position: panel.currentPosition)
        }
    }

    func hasPanel(for workspaceId: String) -> Bool {
        panels[workspaceId] != nil
    }

    var panelCount: Int { panels.count }

    func panelContentView(for workspaceId: String) -> NSView? {
        panels[workspaceId]?.contentView
    }

    /// For testing: triggers the panel's mouseUp callback.
    func simulateMouseUp(for workspaceId: String) {
        guard let panel = panels[workspaceId] else { return }
        panel.onMouseUp?(workspaceId, panel.frame)
    }
}
