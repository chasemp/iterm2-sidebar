import SwiftUI

struct BubbleListView: View {
    let store: BubbleStore
    var onDragChanged: ((String, CGSize) -> Void)?
    var onDragEnded: ((String) -> Void)?
    @State private var showQuickAdd = false
    @State private var renamingBubbleId: String?
    @State private var renameText = ""

    private var dockedBubbles: [Bubble] {
        store.bubbles.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allMin: Bool {
        !dockedBubbles.isEmpty && dockedBubbles.allSatisfy(\.collapsed)
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
                    Image(systemName: allMin ? "macwindow.on.rectangle" : "macwindow.badge.minus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 16)
                }
                .buttonStyle(.plain)
                .help(allMin ? "Restore All" : "Min All")
                .padding(.top, 4)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(dockedBubbles.enumerated()), id: \.element.id) { index, bubble in
                        BubbleView(
                            bubble: bubble,
                            state: store.bubbleState(for: bubble),
                            onTap: {
                                Task { await store.activateBubble(bubble) }
                            },
                            onDoubleTap: {
                                Task { await store.toggleMin(bubble) }
                            },
                            onDragChanged: { translation in
                                onDragChanged?(bubble.id, translation)
                            },
                            onDragEnded: {
                                onDragEnded?(bubble.id)
                            }
                        )
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
                    }
                }
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
    }

    @ViewBuilder
    private func bubbleContextMenu(bubble: Bubble) -> some View {
        Button(bubble.collapsed ? "Restore" : "Min") {
            Task { await store.toggleMin(bubble) }
        }
        Button("Rename Bubble...") {
            renameText = bubble.name
            renamingBubbleId = bubble.id
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
