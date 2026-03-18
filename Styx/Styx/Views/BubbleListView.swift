import SwiftUI

struct BubbleListView: View {
    let store: WorkspaceStore
    var onDragChanged: ((String, CGSize) -> Void)?
    var onDragEnded: ((String) -> Void)?
    @State private var showQuickAdd = false
    @State private var renamingWorkspaceId: String?
    @State private var renameText = ""

    private var dockedWorkspaces: [Workspace] {
        store.workspaces.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allMin: Bool {
        !dockedWorkspaces.isEmpty && dockedWorkspaces.allSatisfy(\.collapsed)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Minimize All / Restore All toggle
            if !dockedWorkspaces.isEmpty {
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
                    ForEach(dockedWorkspaces) { workspace in
                        BubbleView(
                            workspace: workspace,
                            state: store.bubbleState(for: workspace),
                            onTap: {
                                Task { await store.activateWorkspace(workspace) }
                            },
                            onDoubleTap: {
                                Task { await store.toggleMin(workspace) }
                            },
                            onDragChanged: { translation in
                                onDragChanged?(workspace.id, translation)
                            },
                            onDragEnded: {
                                onDragEnded?(workspace.id)
                            }
                        )
                        .contextMenu {
                            bubbleContextMenu(workspace: workspace)
                        }
                        .popover(isPresented: Binding(
                            get: { renamingWorkspaceId == workspace.id },
                            set: { if !$0 { renamingWorkspaceId = nil } }
                        )) {
                            RenamePopover(
                                name: $renameText,
                                onConfirm: {
                                    store.renameWorkspace(workspace.id, to: renameText)
                                    renamingWorkspaceId = nil
                                },
                                onCancel: { renamingWorkspaceId = nil }
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
    private func bubbleContextMenu(workspace: Workspace) -> some View {
        Button(workspace.collapsed ? "Restore" : "Min") {
            Task { await store.toggleMin(workspace) }
        }
        Button("Rename Bubble...") {
            renameText = workspace.name
            renamingWorkspaceId = workspace.id
        }
        Divider()
        Button("Delete Bubble") {
            Task { await store.deleteWorkspace(workspace) }
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
