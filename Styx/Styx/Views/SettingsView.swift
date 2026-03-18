import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var store: WorkspaceStore
    @State private var launchAtLogin = false
    @State private var bubbleSize: Double = 48
    @State private var sidebarOpacity: Double = 1.0

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            hotkeyTab.tabItem { Label("Hotkeys", systemImage: "keyboard") }
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 450, height: 300)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch { launchAtLogin = !newValue }
                }
        }.formStyle(.grouped)
    }

    private var hotkeyTab: some View {
        Form {
            hotkeyRow("Toggle Sidebar", binding: $store.config.hotkeys.toggleSidebar)
            hotkeyRow("Next Workspace", binding: $store.config.hotkeys.nextWorkspace)
            hotkeyRow("Prev Workspace", binding: $store.config.hotkeys.prevWorkspace)
        }.formStyle(.grouped)
    }

    private func hotkeyRow(_ label: String, binding: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("", text: binding).textFieldStyle(.roundedBorder).frame(width: 160)
        }
    }

    private var appearanceTab: some View {
        Form {
            LabeledContent("Bubble Size") {
                Slider(value: $bubbleSize, in: 32...64, step: 4) { Text("\(Int(bubbleSize))pt") }
            }
            LabeledContent("Sidebar Opacity") {
                Slider(value: $sidebarOpacity, in: 0.5...1.0, step: 0.05) { Text("\(Int(sidebarOpacity * 100))%") }
            }
            LabeledContent("Sidebar Width") {
                Slider(value: $store.config.sidebar.width, in: 56...120, step: 4) { Text("\(Int(store.config.sidebar.width))pt") }
            }
        }.formStyle(.grouped)
    }
}
