import AppKit
import SwiftUI

final class SidebarPanel: NSPanel {
    init(contentView: NSView, width: CGFloat = 72) {
        super.init(
            contentRect: NSRect(x: 0, y: 200, width: width, height: 600),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.contentView = contentView
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func updatePosition(_ position: CodablePoint, width: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let pt = position.cgPoint
        let x = max(0, min(pt.x, screen.frame.width - width))
        let y = max(0, min(pt.y, screen.frame.height - frame.height))
        setFrame(NSRect(x: x, y: y, width: width, height: frame.height), display: true)
    }

    func resizeToFit(bubbleCount: Int, bubbleSize: CGFloat = 72) {
        let newHeight = CGFloat(max(bubbleCount, 1)) * (bubbleSize + 8) + 48 + 16
        var f = self.frame
        f.size.height = newHeight
        setFrame(f, display: true, animate: true)
    }
}

@MainActor
final class SidebarPanelController {
    private var panel: SidebarPanel?
    private let store: WorkspaceStore

    var onDragChanged: ((String, CGSize) -> Void)?
    var onDragEnded: ((String) -> Void)?

    init(store: WorkspaceStore) {
        self.store = store
    }

    func show() {
        if panel == nil {
            let rootView = BubbleListView(
                store: store,
                onDragChanged: { [weak self] id, translation in
                    self?.onDragChanged?(id, translation)
                },
                onDragEnded: { [weak self] id in
                    self?.onDragEnded?(id)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            let hostingView = NSHostingView(rootView: rootView)
            panel = SidebarPanel(contentView: hostingView, width: store.config.sidebar.width)
            panel?.updatePosition(store.config.sidebar.position, width: store.config.sidebar.width)
        }
        panel?.orderFront(nil)
        panel?.resizeToFit(bubbleCount: store.workspaces.filter(\.docked).count)
        store.sidebarVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        store.sidebarVisible = false
    }

    func toggle() {
        if store.sidebarVisible { hide() } else { show() }
    }

    func refresh() {
        panel?.resizeToFit(bubbleCount: store.workspaces.filter(\.docked).count)
    }

    var panelFrame: NSRect? { panel?.frame }
}
