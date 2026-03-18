import SwiftUI

struct BubbleListView: View {
    let store: WorkspaceStore
    var onDragChanged: ((String, CGSize) -> Void)?
    var onDragEnded: ((String) -> Void)?
    @State private var showQuickAdd = false

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
                            Button("Delete Workspace") {
                                Task { await store.deleteWorkspace(workspace) }
                            }
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
