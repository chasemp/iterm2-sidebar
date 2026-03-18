import AppKit

struct DockZone {
    var sidebarFrame: NSRect
    var margin: CGFloat

    init(sidebarFrame: NSRect = .zero, margin: CGFloat = 20) {
        self.sidebarFrame = sidebarFrame
        self.margin = margin
    }

    var expandedFrame: NSRect {
        sidebarFrame.insetBy(dx: -margin, dy: -margin)
    }

    func contains(_ point: CGPoint) -> Bool {
        expandedFrame.contains(point)
    }

    func insertionIndex(at point: CGPoint, bubbleCount: Int, bubbleSize: CGFloat = 72, spacing: CGFloat = 8) -> Int {
        let relativeY = sidebarFrame.maxY - point.y
        let slot = (relativeY - 8) / (bubbleSize + spacing)
        return max(0, min(Int(slot), bubbleCount))
    }
}
