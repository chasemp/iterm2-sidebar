import AppKit
import SwiftUI

final class SidebarPanel: NSPanel {
    static let minHeight: CGFloat = 100
    static let maxHeight: CGFloat = 1200
    private static let resizeGripHeight: CGFloat = 16

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
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true

        // Wrap the content with a resize grip view at the bottom
        let wrapper = SidebarContentView(frame: .zero)
        wrapper.autoresizingMask = [.width, .height]
        wrapper.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        self.contentView = wrapper
        self.isMovableByWindowBackground = false
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

    /// Auto-size to fit bubbles. Each bubble row is ~68pt (48 circle + 4 spacing + 12 text + 4 gap).
    /// Plus top button (24), bottom divider+button+handle (~52), and padding.
    func resizeToFit(bubbleCount: Int) {
        let bubbleRowHeight: CGFloat = 68
        let chrome: CGFloat = 80 // top button + bottom controls
        let newHeight = CGFloat(max(bubbleCount, 1)) * bubbleRowHeight + chrome
        let clamped = max(Self.minHeight, min(newHeight, Self.maxHeight))
        var f = self.frame
        let heightDiff = clamped - f.size.height
        f.origin.y -= heightDiff
        f.size.height = clamped
        setFrame(f, display: true, animate: true)
    }

    func resizeByDelta(_ delta: CGFloat) {
        var f = self.frame
        let newHeight = max(Self.minHeight, min(f.size.height + delta, Self.maxHeight))
        let heightDiff = newHeight - f.size.height
        f.origin.y -= heightDiff
        f.size.height = newHeight
        setFrame(f, display: true)
    }
}

// MARK: - Content View (handles resize grip at bottom edge)

final class SidebarContentView: NSView {
    private static let gripHeight: CGFloat = 20

    private enum DragMode { case none, move, resize }
    private var dragMode: DragMode = .none
    private var dragStartMouseY: CGFloat = 0
    private var dragStartFrameOriginY: CGFloat = 0
    private var dragStartFrameHeight: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    /// Set by controller to suppress auto-resize during drag
    var isUserResizing: Bool { dragMode == .resize }

    private func isInGrip(_ event: NSEvent) -> Bool {
        let loc = convert(event.locationInWindow, from: nil)
        return loc.y < Self.gripHeight
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseMoved(with event: NSEvent) {
        if isInGrip(event) {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let panel = window else { return }
        dragStartMouseY = NSEvent.mouseLocation.y
        dragStartFrameOriginY = panel.frame.origin.y
        dragStartFrameHeight = panel.frame.height
        dragMode = isInGrip(event) ? .resize : .move
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel = window else { return }
        let currentY = NSEvent.mouseLocation.y
        let deltaY = currentY - dragStartMouseY

        switch dragMode {
        case .resize:
            // Dragging bottom edge down = shrink, up = grow
            let newHeight = max(SidebarPanel.minHeight, min(dragStartFrameHeight - deltaY, SidebarPanel.maxHeight))
            var f = panel.frame
            f.origin.y = dragStartFrameOriginY + (dragStartFrameHeight - newHeight)
            f.size.height = newHeight
            panel.setFrame(f, display: true)
        case .move:
            var f = panel.frame
            f.origin.y = dragStartFrameOriginY + deltaY
            panel.setFrame(f, display: true)
        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

@MainActor
final class SidebarPanelController {
    private var panel: SidebarPanel?
    private let store: WorkspaceStore
    private let headless: Bool
    private var autoRefreshTask: Task<Void, Never>?
    private var lastBubbleCount: Int = 0

    var onDragChanged: ((String, CGSize) -> Void)?
    var onDragEnded: ((String) -> Void)?

    init(store: WorkspaceStore, headless: Bool = false) {
        self.store = store
        self.headless = headless
        startAutoRefresh()
    }

    private func startAutoRefresh() {
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { break }
                let wrapper = self.panel?.contentView as? SidebarContentView
                let userResizing = wrapper?.isUserResizing ?? false
                let count = self.store.workspaces.filter(\.docked).count
                if count != self.lastBubbleCount && !userResizing {
                    self.lastBubbleCount = count
                    self.panel?.resizeToFit(bubbleCount: count)
                }
            }
        }
    }

    func show() {
        let panelExisted = panel != nil
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
        let bubbleCount = store.workspaces.filter(\.docked).count
        if !headless { panel?.orderFront(nil) }
        panel?.resizeToFit(bubbleCount: bubbleCount)
        store.sidebarVisible = true
        let frame = panel?.frame
        StateLedger.shared.record(
            component: "Sidebar", operation: "show",
            before: ["panelExisted": AnyCodable(panelExisted), "visible": AnyCodable(false)],
            after: [
                "visible": AnyCodable(true),
                "bubbleCount": AnyCodable(bubbleCount),
                "frame": AnyCodable(frame.map { ["x": $0.origin.x, "y": $0.origin.y, "w": $0.size.width, "h": $0.size.height] } as Any? ?? "nil"),
            ]
        )
    }

    func hide() {
        if !headless { panel?.orderOut(nil) }
        store.sidebarVisible = false
        StateLedger.shared.record(
            component: "Sidebar", operation: "hide",
            before: ["visible": AnyCodable(true)],
            after: ["visible": AnyCodable(false)]
        )
    }

    func toggle() {
        if store.sidebarVisible { hide() } else { show() }
    }

    func refresh() {
        let wrapper = panel?.contentView as? SidebarContentView
        if !(wrapper?.isUserResizing ?? false) {
            panel?.resizeToFit(bubbleCount: store.workspaces.filter(\.docked).count)
        }
    }

    var panelFrame: NSRect? { panel?.frame }
}
