import SwiftUI

struct BubbleListView: View {
    let store: BubbleStore
    @State private var showQuickAdd = false
    @State private var renamingBubbleId: String?
    @State private var renameText = ""
    @State private var homeDirBubbleId: String?
    @State private var homeDirText = ""

    // Reorder state
    @State private var draggingBubbleId: String?
    @State private var dragStartIndex: Int?

    private var dockedBubbles: [Bubble] {
        store.bubbles.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allMin: Bool {
        let connected = dockedBubbles.filter { $0.itermWindowId != nil }
        return !connected.isEmpty && connected.allSatisfy(\.collapsed)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Minimize All / Restore All toggle
            if !dockedBubbles.isEmpty {
                Button(action: {
                    Task {
                        if allMin { await store.restoreAll() } else { await store.minAll() }
                    }
                }) {
                    Image(systemName: allMin ? "arrow.up.to.line" : "arrow.down.to.line")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help(allMin ? "Restore All" : "Min All")
                .padding(.top, 8)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Array(dockedBubbles.enumerated()), id: \.element.id) { index, bubble in
                        BubbleView(
                            bubble: bubble,
                            state: store.bubbleState(for: bubble),
                            size: store.config.sidebar.bubbleSize,
                            onTap: {
                                Task { await store.activateBubble(bubble) }
                            },
                            onDoubleTap: {
                                if bubble.itermWindowId == nil {
                                    Task { await store.reviveBubble(bubble) }
                                } else {
                                    Task { await store.toggleMin(bubble) }
                                }
                            },
                            onDragChanged: { translation in
                                handleBubbleDrag(bubble: bubble, index: index, translation: translation)
                            },
                            onDragEnded: {
                                handleBubbleDragEnd(bubble: bubble)
                            }
                        )
                        .opacity(draggingBubbleId == bubble.id ? 0.5 : 1.0)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(index == store.selectedBubbleIndex ? 0.15 : 0))
                                .animation(.easeInOut(duration: 0.15), value: store.selectedBubbleIndex)
                        )
                        .contextMenu {
                            bubbleContextMenu(bubble: bubble)
                        }
                        .popover(isPresented: Binding(
                            get: { renamingBubbleId == bubble.id },
                            set: { if !$0 { renamingBubbleId = nil } }
                        )) {
                            RenamePopover(
                                name: $renameText,
                                onConfirm: {
                                    store.renameBubble(bubble.id, to: renameText)
                                    renamingBubbleId = nil
                                },
                                onCancel: { renamingBubbleId = nil }
                            )
                        }
                        .popover(isPresented: Binding(
                            get: { homeDirBubbleId == bubble.id },
                            set: { if !$0 { homeDirBubbleId = nil } }
                        )) {
                            HomeDirPopover(
                                dir: $homeDirText,
                                onConfirm: {
                                    store.setHomeDir(bubble.id, to: homeDirText)
                                    homeDirBubbleId = nil
                                },
                                onCancel: { homeDirBubbleId = nil }
                            )
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: dockedBubbles.map(\.id))
                .padding(.vertical, 4)
            }

            Divider().padding(.horizontal, 8)

            Button(action: { showQuickAdd.toggle() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            .popover(isPresented: $showQuickAdd) {
                QuickAddView(store: store, isPresented: $showQuickAdd)
            }

            // Bottom padding — resize grip is handled by AppKit at the panel level
            Spacer().frame(height: 12)
        }
        .opacity(store.config.sidebar.opacity)
    }

    // MARK: - Reorder Drag Handling

    private let bubbleRowHeight: CGFloat = 68

    private func handleBubbleDrag(bubble: Bubble, index: Int, translation: CGSize) {
        if dragStartIndex == nil {
            dragStartIndex = index
        }

        draggingBubbleId = bubble.id

        let rowsOffset = Int(round(translation.height / bubbleRowHeight))
        let targetIndex = max(0, min(dragStartIndex! + rowsOffset, dockedBubbles.count - 1))

        if let currentIdx = dockedBubbles.firstIndex(where: { $0.id == bubble.id }),
           targetIndex != currentIdx {
            store.reorderBubble(id: bubble.id, toIndex: targetIndex)
        }
    }

    private func handleBubbleDragEnd(bubble: Bubble) {
        store.saveConfig()
        draggingBubbleId = nil
        dragStartIndex = nil
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func bubbleContextMenu(bubble: Bubble) -> some View {
        if bubble.itermWindowId == nil {
            Button("New Term") {
                Task { await store.reviveBubble(bubble) }
            }
        } else {
            Button(bubble.collapsed ? "Restore" : "Min") {
                Task { await store.toggleMin(bubble) }
            }
        }
        Button("Rename Bubble...") {
            renameText = bubble.name
            renamingBubbleId = bubble.id
        }
        Button("Set Home Dir...") {
            homeDirText = bubble.homeDir ?? ""
            homeDirBubbleId = bubble.id
        }
        Divider()
        Button("Delete Bubble") {
            Task { await store.deleteBubble(bubble) }
        }
    }
}

// MARK: - Rename Popover

struct RenamePopover: View {
    @Binding var name: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Rename Bubble").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onConfirm)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

// MARK: - Home Dir Popover

struct HomeDirPopover: View {
    @Binding var dir: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Home Directory").font(.headline)
            TextField("Directory", text: $dir, prompt: Text("~"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit(onConfirm)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Set", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
