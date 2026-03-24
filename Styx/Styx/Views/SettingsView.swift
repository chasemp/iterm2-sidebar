import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var store: BubbleStore
    @State private var launchAtLogin = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            hotkeyTab.tabItem { Label("Hotkeys", systemImage: "keyboard") }
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            terminalTab.tabItem { Label("Terminal", systemImage: "terminal") }
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
            hotkeyRow("Next Bubble", binding: $store.config.hotkeys.nextBubble)
            hotkeyRow("Prev Bubble", binding: $store.config.hotkeys.prevBubble)
        }.formStyle(.grouped)
    }

    private func hotkeyRow(_ label: String, binding: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("", text: binding).textFieldStyle(.roundedBorder).frame(width: 160)
        }
    }

    private var terminalTab: some View {
        Form {
            Section("Bubble Identity") {
                Toggle("Show bubble badge in terminal", isOn: $store.config.terminal.showBubbleBadge)
                    .help("Display the bubble name as a watermark in the iTerm2 session")
                Toggle("Set $STYX_BUBBLE env var", isOn: $store.config.terminal.setBubbleEnvVar)
                    .help("Export STYX_BUBBLE=<name> in new sessions so you can use it in your shell prompt")
            }

            Section("Bubble Prompt") {
                Text("When $STYX_BUBBLE is enabled, add these lines to the end of ~/.zshrc:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("""
                _styx_prompt() {
                  [[ -n "$STYX_BUBBLE" ]] || return
                  local hex="${STYX_BUBBLE_COLOR#\\#}"
                  if [[ -n "$hex" && ${#hex} -eq 6 ]]; then
                    local r=$((16#${hex[1,2]})) g=$((16#${hex[3,4]})) b=$((16#${hex[5,6]}))
                    echo -n "%{\\e[38;2;${r};${g};${b}m%}[$STYX_BUBBLE]%{\\e[0m%} "
                  else
                    echo -n "[$STYX_BUBBLE] "
                  fi
                }
                PROMPT='$(_styx_prompt)'"$PROMPT"
                """)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                Text("Shows [bubble-name] before your prompt only in Styx sessions. Normal terminals are unaffected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Toggle("Show window controls", isOn: $store.config.sidebar.showWindowControls)
                .help("Show close/minimize buttons on the sidebar (applies on next toggle)")
            LabeledContent("Bubble Size") {
                Slider(value: $store.config.sidebar.bubbleSize, in: 32...64, step: 4) { Text("\(Int(store.config.sidebar.bubbleSize))pt") }
            }
            LabeledContent("Sidebar Opacity") {
                Slider(value: $store.config.sidebar.opacity, in: 0.5...1.0, step: 0.05) { Text("\(Int(store.config.sidebar.opacity * 100))%") }
            }
            LabeledContent("Sidebar Width") {
                Slider(value: $store.config.sidebar.width, in: 56...120, step: 4) { Text("\(Int(store.config.sidebar.width))pt") }
            }
        }.formStyle(.grouped)
    }
}
