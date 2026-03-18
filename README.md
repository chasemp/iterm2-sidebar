# Styx — iTerm2 Workspace Manager

A native macOS menubar app that provides a floating sidebar of "bubbles," each representing a named workspace mapped to an iTerm2 window with its tabs. Bubbles can be clicked to switch context, dragged out to float independently, or snapped back into the sidebar.

## Prerequisites

- macOS 14+ (Sonoma)
- Python 3.9+ with `pip install iterm2`
- iTerm2 with Python API server enabled (Preferences > General > Magic > Enable Python API server)
- Xcode 15.4+

## Build

```bash
cd Styx
xcodebuild -project Styx.xcodeproj -scheme Styx -configuration Debug build
```

## Test

```bash
cd Styx
xcodebuild -project Styx.xcodeproj -scheme Styx -configuration Debug test
```

188 behavioral tests, 0 warnings. All production code written test-first via BDD.

## Run

Open `Styx/Styx.xcodeproj` in Xcode and run, or launch the built app from DerivedData. A menubar icon appears — no dock icon.

On first launch, macOS will prompt for Accessibility permission (needed for global hotkeys).

## Architecture

```
┌──────────────┐     ┌────────────────┐     ┌───────────────┐
│ MenuBarExtra  │────>│ WorkspaceStore │<--->│ ITerm2Bridge   │
└──────────────┘     └──────┬─────────┘     └───────┬───────┘
                            │                        │ JSON/stdin/stdout
                     ┌──────v─────────┐     ┌───────v───────┐
                     │ SidebarPanel    │     │ bridge_daemon  │
                     │ (NSPanel)       │     │ (Python 3.9+)  │
                     │  ┌────────────┐ │     └───────┬───────┘
                     │  │ BubbleList │ │             │ iterm2 PyPI
                     │  └────────────┘ │     ┌───────v───────┐
                     └────────────────┘     │  iTerm2 API    │
                                            └───────────────┘
```

## Features

- Floating non-activating sidebar with workspace bubbles
- Click bubble to switch iTerm2 window
- Drag bubble off sidebar to float independently
- Drag floating bubble back to redock
- Recall All snaps every floating bubble home
- Create workspaces from templates or blank
- Capture current iTerm2 window as a workspace
- Rename workspaces via context menu
- Focus tracking with colored ring indicators (green=focused, blue=active, gray=dormant)
- Global hotkeys: Ctrl+1-9, configurable toggle/next/prev
- Config persists to ~/Library/Application Support/Styx/workspaces.json
- Bridge auto-restarts on crash, window liveness polling
- Settings: launch at login, hotkeys, appearance

## Project Structure

```
Styx/
├── Styx.xcodeproj/
├── Styx/
│   ├── StyxApp.swift              # @main, MenuBarExtra, AppDelegate
│   ├── Bridge/
│   │   ├── BridgeProtocol.swift   # Protocol, Codable types, FocusEvent
│   │   └── ITerm2Bridge.swift     # Actor: subprocess mgmt, JSON protocol
│   ├── Models/
│   │   ├── Workspace.swift        # Workspace, WorkspaceTab, Config, Templates
│   │   ├── WorkspaceStore.swift   # @Observable store, persistence, bridge ops
│   │   ├── BubbleState.swift      # focused/active/dormant with colors
│   │   └── HexColor.swift         # Hex string to RGB parsing
│   ├── Views/
│   │   ├── SidebarPanel.swift     # NSPanel + controller
│   │   ├── BubbleView.swift       # Single bubble with state ring
│   │   ├── BubbleListView.swift   # Vertical bubble list + rename popover
│   │   ├── FloatingBubblePanel.swift  # Undocked bubble panel + manager
│   │   ├── QuickAddView.swift     # New workspace popover
│   │   └── SettingsView.swift     # Preferences tabs
│   ├── Hotkeys/
│   │   ├── HotkeyParser.swift     # String to key combo parsing
│   │   ├── HotkeyRegistrar.swift  # Carbon hotkey registration
│   │   └── AccessibilityChecker.swift  # AXIsProcessTrusted wrapper
│   └── Drag/
│       ├── BubbleDragStateMachine.swift  # idle/pending/active transitions
│       └── DockZone.swift         # Hit-test geometry for snap-back
├── StyxBridge/
│   ├── bridge_daemon.py           # Python daemon: stdin/stdout JSON
│   ├── commands.py                # iTerm2 API command handlers
│   └── requirements.txt
├── Tests/
│   └── StyxTests.swift            # 188 behavioral tests
└── docs/
    └── lesson-macos-permission-prompts.md
```
