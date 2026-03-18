import SwiftUI

struct BubbleView: View {
    let workspace: Workspace
    let state: BubbleState
    let size: CGFloat
    let onTap: () -> Void
    var onDoubleTap: (() -> Void)?
    var onDragChanged: ((CGSize) -> Void)?
    var onDragEnded: (() -> Void)?

    @State private var lastClickTime: Date = .distantPast

    init(
        workspace: Workspace,
        state: BubbleState,
        size: CGFloat = 48,
        onTap: @escaping () -> Void,
        onDoubleTap: (() -> Void)? = nil,
        onDragChanged: ((CGSize) -> Void)? = nil,
        onDragEnded: (() -> Void)? = nil
    ) {
        self.workspace = workspace
        self.state = state
        self.size = size
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(state.ringColor, lineWidth: 3)
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color(hex: workspace.color).opacity(0.2))
                    .frame(width: size - 6, height: size - 6)
                Image(systemName: workspace.icon)
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(Color(hex: workspace.color))
            }
            .opacity(state.opacity)

            Text(workspace.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(width: size + 16)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in onDragChanged?(value.translation) }
                .onEnded { _ in onDragEnded?() }
        )
        .onTapGesture {
            let now = Date()
            let interval = now.timeIntervalSince(lastClickTime)
            StateLedger.shared.record(
                component: "BubbleView", operation: "tapGesture",
                before: ["workspaceId": AnyCodable(workspace.id), "lastClickInterval": AnyCodable(interval)],
                after: ["isDoubleTap": AnyCodable(interval < 0.35)]
            )
            if interval < 0.35 {
                onDoubleTap?()
                lastClickTime = .distantPast
            } else {
                lastClickTime = now
                let captured = now
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if self.lastClickTime == captured {
                        self.onTap()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = HexColor.parse(hex)
        self.init(red: r, green: g, blue: b)
    }
}
