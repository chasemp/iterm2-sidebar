# Styx — Project Plan

## Status: Core Complete

All core features implemented and tested via strict BDD. 188 tests, 0 warnings.

## What's Done

### Phase 0 — Foundation (Bridge)
- [x] Python bridge daemon with stdin/stdout JSON protocol
- [x] Commands: ping, list_windows, activate_window, create_window, create_tab, close_window, activate_tab, list_tabs, get_active_window
- [x] Swift BridgeService protocol with ITerm2Bridge actor implementation
- [x] Auto-restart on subprocess crash
- [x] BridgeRequest/BridgeResponse Codable types

### Phase 1 — App Shell (Sidebar + Bubbles)
- [x] MenuBarExtra with menubar icon, no dock icon
- [x] Non-activating floating NSPanel sidebar
- [x] BubbleView with color ring state indicator, SF Symbol, name label
- [x] BubbleListView with scrollable vertical layout
- [x] WorkspaceStore with config persistence
- [x] Click bubble activates iTerm2 window
- [x] Sidebar does not steal keyboard focus

### Phase 2 — Workspace Lifecycle
- [x] Create workspace via QuickAdd popover (name, color, icon, templates)
- [x] Delete workspace via context menu
- [x] Focus tracking via FocusMonitor events
- [x] Global hotkeys: Ctrl+1-9, configurable toggle/next/prev
- [x] Hotkey re-registration on config change
- [x] Capture current iTerm2 window as workspace (auto-names from session)
- [x] Rename workspace via context menu popover
- [x] Window liveness polling (10s interval)

### Phase 3 — Drag/Dock
- [x] BubbleDragStateMachine (idle/pending/active transitions)
- [x] Drag bubble off sidebar creates floating panel
- [x] Drag floating bubble over sidebar redocks it
- [x] DockZone hit-test with 20pt margin
- [x] Recall All snaps all floating bubbles home
- [x] Position persistence for floating bubbles

### Phase 4 — Polish
- [x] Settings: launch at login (SMAppService), hotkeys, appearance
- [x] Templates: Web Dev, DevOps predefined configs
- [x] Bridge health: auto-restart, menubar status indicator
- [x] iTerm2 reachability tracking
- [x] Accessibility permission check on launch (guarded from tests)
- [x] Headless mode for clean test execution
- [x] Python bridge bundled in app via build phase

## What's Remaining

### Polish (not blocking)
- [ ] Animations: sidebar slide, undock scale-up, redock shrink
- [ ] First-launch onboarding: Python setup guide, iTerm2 API enable instructions
- [ ] Configurable poll interval (currently hardcoded 10s)
- [ ] Tab cycling hotkeys (Ctrl+Alt+Tab)
- [ ] Drag ghost panel during undock (visual feedback while dragging)
- [ ] Sidebar position save on window move

### Future Ideas
- [ ] Workspace color change via context menu
- [ ] Workspace icon change via context menu
- [ ] Import/export config
- [ ] Multiple sidebar positions (left/right/top/bottom)
- [ ] Workspace groups/folders
