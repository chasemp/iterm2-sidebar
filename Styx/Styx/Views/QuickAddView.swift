import SwiftUI

struct QuickAddView: View {
    let store: BubbleStore
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var homeDir = ""
    @State private var color = "#4A90D9"
    @State private var icon = "terminal"

    private let colorOptions = [
        "#FF6B6B", "#4ECDC4", "#4A90D9", "#A77DC2",
        "#F7B731", "#26DE81", "#FC5C65", "#45AAF2",
    ]

    private let iconOptions = [
        "terminal", "server.rack", "globe", "doc.text",
        "hammer", "wrench.and.screwdriver", "cpu", "network",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Bubble").font(.headline)

            TextField("Bubble name", text: $name).textFieldStyle(.roundedBorder)

            TextField("Home directory", text: $homeDir, prompt: Text("~"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            VStack(alignment: .leading, spacing: 4) {
                Text("Color").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 20, height: 20)
                            .overlay { if hex == color { Circle().stroke(.white, lineWidth: 2) } }
                            .onTapGesture { color = hex }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Icon").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(iconOptions, id: \.self) { sfSymbol in
                        Image(systemName: sfSymbol).font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(icon == sfSymbol ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .onTapGesture { icon = sfSymbol }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("Create") { Task { await createBubble() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func createBubble() async {
        let resolvedDir = homeDir.trimmingCharacters(in: .whitespaces)
        let dir = resolvedDir.isEmpty ? "~" : resolvedDir
        let tabs = [BubbleTab(name: "shell", dir: dir, cmd: nil)]
        await store.createBubble(
            name: name.trimmingCharacters(in: .whitespaces),
            color: color,
            icon: icon,
            tabs: tabs,
            homeDir: resolvedDir.isEmpty ? nil : resolvedDir
        )
        isPresented = false
    }
}
