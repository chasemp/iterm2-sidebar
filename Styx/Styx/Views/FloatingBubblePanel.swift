import AppKit
import SwiftUI

final class FloatingBubblePanel: NSPanel {
    let bubbleId: String
    var onMouseUp: ((String, NSRect) -> Void)?

    init(bubbleId: String, position: CGPoint, contentView: NSView? = nil) {
        self.bubbleId = bubbleId
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
        onMouseUp?(bubbleId, frame)
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
    private let store: BubbleStore

    var onRedockCheck: ((String, NSRect) -> Void)?
    private let headless: Bool

    init(store: BubbleStore, headless: Bool = false) {
        self.store = store
        self.headless = headless
    }

    func showFloatingBubble(for bubble: Bubble) {
        guard panels[bubble.id] == nil else { return }
        let position = bubble.floatingPosition?.cgPoint ?? CGPoint(x: 100, y: 100)

        // Create bubble content
        let bubbleView = BubbleView(
            bubble: bubble,
            state: store.bubbleState(for: bubble),
            onTap: { [weak self] in
                Task { await self?.store.activateBubble(bubble) }
            }
        )
        let hostingView = NSHostingView(rootView: bubbleView)

        let panel = FloatingBubblePanel(
            bubbleId: bubble.id,
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
        panels[bubble.id] = panel
    }

    func hideFloatingBubble(for bubbleId: String) {
        if !headless { panels[bubbleId]?.orderOut(nil) }
        panels.removeValue(forKey: bubbleId)
    }

    func recallAll() {
        for id in panels.keys {
            store.redockBubble(id, atSortOrder: store.bubbles.filter(\.docked).count)
            if !headless { panels[id]?.orderOut(nil) }
        }
        panels.removeAll()
    }

    func refresh() {
        let undocked = store.bubbles.filter { !$0.docked }
        let undockedIds = Set(undocked.map(\.id))

        for id in panels.keys where !undockedIds.contains(id) {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
        }
        for bubble in undocked where panels[bubble.id] == nil {
            showFloatingBubble(for: bubble)
        }
    }

    func savePositions() {
        for (id, panel) in panels {
            store.undockBubble(id, position: panel.currentPosition)
        }
    }

    func hasPanel(for bubbleId: String) -> Bool {
        panels[bubbleId] != nil
    }

    var panelCount: Int { panels.count }

    func panelContentView(for bubbleId: String) -> NSView? {
        panels[bubbleId]?.contentView
    }

    /// For testing: triggers the panel's mouseUp callback.
    func simulateMouseUp(for bubbleId: String) {
        guard let panel = panels[bubbleId] else { return }
        panel.onMouseUp?(bubbleId, panel.frame)
    }
}
