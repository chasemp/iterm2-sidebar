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

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(dockedWorkspaces) { workspace in
                        BubbleView(
                            workspace: workspace,
                            state: store.bubbleState(for: workspace),
                            onTap: {
                                Task { await store.activateWorkspace(workspace) }
                            },
                            onDragChanged: { translation in
                                onDragChanged?(workspace.id, translation)
                            },
                            onDragEnded: {
                                onDragEnded?(workspace.id)
                            }
                        )
                        .contextMenu {
                            Button("Rename...") {
                                renameText = workspace.name
                                renamingWorkspaceId = workspace.id
                            }
                            Divider()
                            Button("Delete Workspace") {
                                Task { await store.deleteWorkspace(workspace) }
                            }
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
                .padding(.vertical, 8)
            }

            Divider().padding(.horizontal, 8)

            Button(action: { showQuickAdd.toggle() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .popover(isPresented: $showQuickAdd) {
                QuickAddView(store: store, isPresented: $showQuickAdd)
            }
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
            Text("Rename Workspace").font(.headline)
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
