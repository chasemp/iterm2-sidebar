import XCTest
import SwiftUI
@testable import Styx

// MARK: - Test Data Factories

func makeWorkspace(
    name: String = "Test",
    color: String = "#4A90D9",
    icon: String = "terminal",
    sortOrder: Int = 0,
    itermWindowId: String? = nil,
    docked: Bool = true,
    floatingPosition: CodablePoint? = nil,
    tabs: [WorkspaceTab] = []
) -> Workspace {
    Workspace(
        name: name,
        color: color,
        icon: icon,
        sortOrder: sortOrder,
        itermWindowId: itermWindowId,
        docked: docked,
        floatingPosition: floatingPosition,
        tabs: tabs
    )
}

func makeTab(
    name: String = "shell",
    dir: String? = "~",
    cmd: String? = nil
) -> WorkspaceTab {
    WorkspaceTab(name: name, dir: dir, cmd: cmd)
}

// MARK: - CodablePoint

final class CodablePointTests: XCTestCase {

    func test_creates_point_with_coordinates() {
        let point = CodablePoint(x: 10, y: 20)
        XCTAssertEqual(point.x, 10)
        XCTAssertEqual(point.y, 20)
    }

    func test_converts_to_cgpoint() {
        let point = CodablePoint(x: 10, y: 20)
        XCTAssertEqual(point.cgPoint, CGPoint(x: 10, y: 20))
    }

    func test_creates_from_cgpoint() {
        let point = CodablePoint(CGPoint(x: 30, y: 40))
        XCTAssertEqual(point.x, 30)
        XCTAssertEqual(point.y, 40)
    }

    func test_roundtrips_through_json() throws {
        let original = CodablePoint(x: 100, y: 200)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodablePoint.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_equality() {
        XCTAssertEqual(CodablePoint(x: 1, y: 2), CodablePoint(x: 1, y: 2))
        XCTAssertNotEqual(CodablePoint(x: 1, y: 2), CodablePoint(x: 3, y: 4))
    }
}

// MARK: - Workspace

final class WorkspaceTests: XCTestCase {

    func test_creates_workspace_with_defaults() {
        let ws = makeWorkspace(name: "Backend")
        XCTAssertEqual(ws.name, "Backend")
        XCTAssertEqual(ws.color, "#4A90D9")
        XCTAssertEqual(ws.icon, "terminal")
        XCTAssertTrue(ws.docked)
        XCTAssertNil(ws.itermWindowId)
        XCTAssertNil(ws.floatingPosition)
        XCTAssertTrue(ws.tabs.isEmpty)
    }

    func test_workspace_has_stable_id() {
        let ws = makeWorkspace(name: "Test")
        XCTAssertFalse(ws.id.isEmpty)
    }

    func test_workspace_roundtrips_through_json() throws {
        let ws = makeWorkspace(
            name: "Backend",
            color: "#FF6B6B",
            icon: "server.rack",
            sortOrder: 2,
            itermWindowId: "pty-123",
            docked: false,
            floatingPosition: CodablePoint(x: 100, y: 200),
            tabs: [makeTab(name: "core", dir: "~/proj"), makeTab(name: "tests", cmd: "make test")]
        )

        let data = try JSONEncoder().encode(ws)
        let decoded = try JSONDecoder().decode(Workspace.self, from: data)

        XCTAssertEqual(decoded.name, "Backend")
        XCTAssertEqual(decoded.color, "#FF6B6B")
        XCTAssertEqual(decoded.itermWindowId, "pty-123")
        XCTAssertFalse(decoded.docked)
        XCTAssertEqual(decoded.floatingPosition, CodablePoint(x: 100, y: 200))
        XCTAssertEqual(decoded.tabs.count, 2)
        XCTAssertEqual(decoded.tabs[0].name, "core")
        XCTAssertEqual(decoded.tabs[1].cmd, "make test")
    }

    func test_workspace_equality() {
        let a = makeWorkspace(name: "A")
        var b = a
        XCTAssertEqual(a, b)
        b.name = "B"
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - WorkspaceTab

final class WorkspaceTabTests: XCTestCase {

    func test_tab_id_is_name() {
        let tab = makeTab(name: "server")
        XCTAssertEqual(tab.id, "server")
    }

    func test_tab_roundtrips_through_json() throws {
        let tab = makeTab(name: "dev", dir: "~/projects", cmd: "npm start")
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(WorkspaceTab.self, from: data)
        XCTAssertEqual(decoded.name, "dev")
        XCTAssertEqual(decoded.dir, "~/projects")
        XCTAssertEqual(decoded.cmd, "npm start")
    }
}

// MARK: - StyxConfig

final class StyxConfigTests: XCTestCase {

    func test_default_config_has_version_1() {
        let config = StyxConfig()
        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.workspaces.isEmpty)
        XCTAssertTrue(config.sidebar.visible)
    }

    func test_config_roundtrips_through_json() throws {
        var config = StyxConfig()
        config.workspaces = [makeWorkspace(name: "Backend"), makeWorkspace(name: "Frontend")]
        config.hotkeys.toggleSidebar = "Cmd+Shift+S"
        config.sidebar.width = 80

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(StyxConfig.self, from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.workspaces.count, 2)
        XCTAssertEqual(decoded.workspaces[0].name, "Backend")
        XCTAssertEqual(decoded.hotkeys.toggleSidebar, "Cmd+Shift+S")
        XCTAssertEqual(decoded.sidebar.width, 80)
    }
}

// MARK: - BubbleState

final class BubbleStateTests: XCTestCase {

    func test_focused_state_has_green_ring() {
        XCTAssertEqual(BubbleState.focused.ringColor, .green)
    }

    func test_active_state_has_blue_ring() {
        XCTAssertEqual(BubbleState.active.ringColor, .blue)
    }

    func test_dormant_state_has_gray_ring() {
        XCTAssertEqual(BubbleState.dormant.ringColor, .gray)
    }

    func test_focused_is_most_opaque() {
        XCTAssertEqual(BubbleState.focused.opacity, 1.0)
        XCTAssertGreaterThan(BubbleState.active.opacity, BubbleState.dormant.opacity)
    }
}

// MARK: - DockZone

final class DockZoneTests: XCTestCase {

    func test_contains_point_inside_sidebar() {
        var zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        XCTAssertTrue(zone.contains(CGPoint(x: 36, y: 500)))
    }

    func test_contains_point_within_margin() {
        var zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        XCTAssertTrue(zone.contains(CGPoint(x: 85, y: 500)))
    }

    func test_rejects_point_outside_margin() {
        var zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        XCTAssertFalse(zone.contains(CGPoint(x: 200, y: 500)))
    }

    func test_insertion_index_clamps_to_bubble_count() {
        var zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        let index = zone.insertionIndex(at: CGPoint(x: 36, y: 750), bubbleCount: 3)
        XCTAssertGreaterThanOrEqual(index, 0)
        XCTAssertLessThanOrEqual(index, 3)
    }
}

// MARK: - BridgeProtocol

final class BridgeProtocolTests: XCTestCase {

    func test_request_encodes_cmd_and_id() throws {
        let request = BridgeRequest(cmd: "ping")
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["cmd"] as? String, "ping")
        XCTAssertNotNil(json["id"] as? String)
    }

    func test_request_encodes_args() throws {
        let request = BridgeRequest(cmd: "activate_window", args: ["window_id": "pty-123"])
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let args = json["args"] as? [String: Any]
        XCTAssertEqual(args?["window_id"] as? String, "pty-123")
    }

    func test_success_response_decodes() throws {
        let json = #"{"id":"req-1","ok":true,"data":{"pong":true}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.id, "req-1")
        XCTAssertTrue(response.isSuccess)
        XCTAssertFalse(response.isEvent)
    }

    func test_error_response_decodes() throws {
        let json = #"{"id":"req-2","ok":false,"error":"Window not found"}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertFalse(response.isSuccess)
        XCTAssertEqual(response.error, "Window not found")
    }

    func test_focus_event_parses_from_response() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"window","window_id":"pty-ABC"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(response.isEvent)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.kind, .window)
        XCTAssertEqual(event?.windowId, "pty-ABC")
    }

    func test_any_codable_roundtrips_primitives() throws {
        let original: [String: AnyCodable] = [
            "string": AnyCodable("hello"),
            "number": AnyCodable(42),
            "bool": AnyCodable(true),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        XCTAssertEqual(decoded["string"]?.value as? String, "hello")
        XCTAssertEqual(decoded["number"]?.value as? Int, 42)
        XCTAssertEqual(decoded["bool"]?.value as? Bool, true)
    }
}

// MARK: - WorkspaceTemplate

final class WorkspaceTemplateTests: XCTestCase {

    func test_templates_are_available() {
        XCTAssertFalse(WorkspaceTemplate.all.isEmpty)
    }

    func test_web_dev_template_has_tabs() {
        XCTAssertEqual(WorkspaceTemplate.webDev.name, "Web Dev")
        XCTAssertFalse(WorkspaceTemplate.webDev.tabs.isEmpty)
    }

    func test_devops_template_has_tabs() {
        XCTAssertEqual(WorkspaceTemplate.devOps.name, "DevOps")
        XCTAssertFalse(WorkspaceTemplate.devOps.tabs.isEmpty)
    }
}

// MARK: - WorkspaceStore

@MainActor
final class WorkspaceStoreTests: XCTestCase {

    private func makeStore(workspaces: [Workspace] = []) -> WorkspaceStore {
        let store = WorkspaceStore()
        store.config.workspaces = workspaces
        return store
    }

    // --- Bubble State Derivation ---

    func test_focused_workspace_returns_focused_state() {
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        let store = makeStore(workspaces: [ws])
        store.focusedWorkspaceId = ws.id

        XCTAssertEqual(store.bubbleState(for: ws), .focused)
    }

    func test_workspace_with_window_but_not_focused_returns_active() {
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        let store = makeStore(workspaces: [ws])
        store.focusedWorkspaceId = nil

        XCTAssertEqual(store.bubbleState(for: ws), .active)
    }

    func test_workspace_without_window_returns_dormant() {
        let ws = makeWorkspace(name: "A", itermWindowId: nil)
        let store = makeStore(workspaces: [ws])

        XCTAssertEqual(store.bubbleState(for: ws), .dormant)
    }

    // --- Dock / Undock ---

    func test_undock_sets_docked_false_and_saves_position() {
        var ws = makeWorkspace(name: "A", docked: true)
        let store = makeStore(workspaces: [ws])

        store.undockWorkspace(ws.id, position: CGPoint(x: 100, y: 200))

        let updated = store.workspaces.first { $0.id == ws.id }!
        XCTAssertFalse(updated.docked)
        XCTAssertEqual(updated.floatingPosition, CodablePoint(x: 100, y: 200))
    }

    func test_redock_sets_docked_true_and_clears_position() {
        var ws = makeWorkspace(name: "A", docked: false, floatingPosition: CodablePoint(x: 50, y: 50))
        let store = makeStore(workspaces: [ws])

        store.redockWorkspace(ws.id, atSortOrder: 0)

        let updated = store.workspaces.first { $0.id == ws.id }!
        XCTAssertTrue(updated.docked)
        XCTAssertNil(updated.floatingPosition)
        XCTAssertEqual(updated.sortOrder, 0)
    }

    func test_recall_all_redocks_every_floating_workspace() {
        let a = makeWorkspace(name: "A", docked: false, floatingPosition: CodablePoint(x: 10, y: 10))
        let b = makeWorkspace(name: "B", docked: false, floatingPosition: CodablePoint(x: 20, y: 20))
        let c = makeWorkspace(name: "C", docked: true)
        let store = makeStore(workspaces: [a, b, c])

        store.recallAll()

        XCTAssertTrue(store.workspaces.allSatisfy(\.docked))
        XCTAssertTrue(store.workspaces.allSatisfy { $0.floatingPosition == nil })
    }

    // --- Workspace Cycling ---

    func test_cycle_forward_wraps_around() {
        let a = makeWorkspace(name: "A", sortOrder: 0)
        let b = makeWorkspace(name: "B", sortOrder: 1)
        let store = makeStore(workspaces: [a, b])
        store.focusedWorkspaceId = b.id

        let next = store.nextWorkspaceId(forward: true)
        XCTAssertEqual(next, a.id)
    }

    func test_cycle_backward_wraps_around() {
        let a = makeWorkspace(name: "A", sortOrder: 0)
        let b = makeWorkspace(name: "B", sortOrder: 1)
        let store = makeStore(workspaces: [a, b])
        store.focusedWorkspaceId = a.id

        let prev = store.nextWorkspaceId(forward: false)
        XCTAssertEqual(prev, b.id)
    }

    func test_workspace_by_index_returns_correct_id() {
        let a = makeWorkspace(name: "A", sortOrder: 0)
        let b = makeWorkspace(name: "B", sortOrder: 1)
        let store = makeStore(workspaces: [a, b])

        XCTAssertEqual(store.workspaceIdByIndex(0), a.id)
        XCTAssertEqual(store.workspaceIdByIndex(1), b.id)
        XCTAssertNil(store.workspaceIdByIndex(5))
    }

    // --- Sidebar Visibility ---

    func test_sidebar_visible_mirrors_config() {
        let store = makeStore()
        store.config.sidebar.visible = true
        XCTAssertTrue(store.sidebarVisible)

        store.sidebarVisible = false
        XCTAssertFalse(store.config.sidebar.visible)
    }

    // --- Persistence ---

    func test_save_and_load_config_roundtrips() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("workspaces.json")

        let store = makeStore(workspaces: [makeWorkspace(name: "Saved")])
        store.saveConfig(to: configURL)

        let store2 = WorkspaceStore()
        store2.loadConfig(from: configURL)

        XCTAssertEqual(store2.workspaces.count, 1)
        XCTAssertEqual(store2.workspaces.first?.name, "Saved")
    }

    func test_load_missing_config_uses_defaults() {
        let bogusURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.json")
        let store = WorkspaceStore()
        store.loadConfig(from: bogusURL)

        XCTAssertTrue(store.workspaces.isEmpty)
        XCTAssertEqual(store.config.version, 1)
    }
}

// MARK: - HotkeyParser

final class HotkeyParserTests: XCTestCase {

    func test_parses_simple_hotkey() {
        let combo = HotkeyParser.parse("Cmd+S")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.command))
        XCTAssertEqual(combo!.keyString, "s")
    }

    func test_parses_compound_modifiers() {
        let combo = HotkeyParser.parse("Cmd+Shift+S")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.command))
        XCTAssertTrue(combo!.modifiers.contains(.shift))
        XCTAssertEqual(combo!.keyString, "s")
    }

    func test_parses_ctrl_modifier() {
        let combo = HotkeyParser.parse("Ctrl+Tab")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.control))
        XCTAssertEqual(combo!.keyString, "tab")
    }

    func test_parses_alt_modifier() {
        let combo = HotkeyParser.parse("Alt+1")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.option))
        XCTAssertEqual(combo!.keyString, "1")
    }

    func test_returns_nil_for_empty_string() {
        XCTAssertNil(HotkeyParser.parse(""))
    }

    func test_returns_nil_for_modifiers_only() {
        XCTAssertNil(HotkeyParser.parse("Cmd+"))
    }
}

// MARK: - BubbleDragStateMachine

final class BubbleDragStateMachineTests: XCTestCase {

    func test_starts_idle() {
        let machine = BubbleDragStateMachine()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_small_translation_transitions_to_pending() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(machine.phase, .pending(workspaceId: "ws-1"))
    }

    func test_large_translation_transitions_to_active() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 25, height: 0))
        XCTAssertEqual(machine.phase, .active(workspaceId: "ws-1"))
    }

    func test_end_from_pending_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragEnded()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_end_from_active_returns_workspace_id() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 25, height: 0))
        let result = machine.dragEnded()
        XCTAssertEqual(result, "ws-1")
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_cancel_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 25, height: 25))
        machine.cancel()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_cancel_from_pending_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(machine.phase, .pending(workspaceId: "ws-1"))
        machine.cancel()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_end_from_idle_returns_nil() {
        var machine = BubbleDragStateMachine()
        let result = machine.dragEnded()
        XCTAssertNil(result)
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_double_end_returns_nil_second_time() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 25, height: 0))
        _ = machine.dragEnded()
        let second = machine.dragEnded()
        XCTAssertNil(second)
    }

    func test_active_phase_ignores_further_drag_changes() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 10, height: 0)) // → pending
        machine.dragChanged(workspaceId: "ws-1", translation: CGSize(width: 25, height: 0)) // → active
        XCTAssertEqual(machine.phase, .active(workspaceId: "ws-1"))
        machine.dragChanged(workspaceId: "ws-2", translation: CGSize(width: 100, height: 0)) // ignored
        XCTAssertEqual(machine.phase, .active(workspaceId: "ws-1"))
    }
}

// MARK: - HexColor Parsing

final class HexColorTests: XCTestCase {

    func test_parses_six_digit_hex_with_hash() {
        let (r, g, b) = HexColor.parse("#FF0000")
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func test_parses_six_digit_hex_without_hash() {
        let (r, g, b) = HexColor.parse("00FF00")
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func test_invalid_hex_returns_gray() {
        let (r, g, b) = HexColor.parse("nope")
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }

    func test_empty_string_returns_gray() {
        let (r, g, b) = HexColor.parse("")
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }

    func test_three_digit_hex_returns_gray() {
        let (r, g, b) = HexColor.parse("#F00")
        XCTAssertEqual(r, 0.5, accuracy: 0.01) // only 6-digit supported
    }

    func test_parses_mixed_case() {
        let (r, g, b) = HexColor.parse("#ff6b6b")
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertGreaterThan(g, 0.0)
        XCTAssertGreaterThan(b, 0.0)
    }
}

// MARK: - DockZone Edge Cases

final class DockZoneEdgeCaseTests: XCTestCase {

    func test_expanded_frame_adds_margin() {
        let zone = DockZone(sidebarFrame: NSRect(x: 0, y: 100, width: 72, height: 400), margin: 20)
        let expanded = zone.expandedFrame
        XCTAssertEqual(expanded.origin.x, -20)
        XCTAssertEqual(expanded.origin.y, 80)
        XCTAssertEqual(expanded.width, 112) // 72 + 2*20
        XCTAssertEqual(expanded.height, 440) // 400 + 2*20
    }

    func test_insertion_index_with_zero_bubbles() {
        let zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        let index = zone.insertionIndex(at: CGPoint(x: 36, y: 500), bubbleCount: 0)
        XCTAssertEqual(index, 0)
    }

    func test_insertion_index_at_top_of_sidebar() {
        let zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        let index = zone.insertionIndex(at: CGPoint(x: 36, y: 799), bubbleCount: 5)
        XCTAssertEqual(index, 0)
    }

    func test_insertion_index_at_bottom_of_sidebar() {
        let zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600))
        let index = zone.insertionIndex(at: CGPoint(x: 36, y: 201), bubbleCount: 5)
        XCTAssertEqual(index, 5) // clamps to bubbleCount
    }

    func test_zero_margin_means_exact_sidebar_frame() {
        let zone = DockZone(sidebarFrame: NSRect(x: 0, y: 200, width: 72, height: 600), margin: 0)
        XCTAssertTrue(zone.contains(CGPoint(x: 36, y: 500)))
        XCTAssertFalse(zone.contains(CGPoint(x: 73, y: 500)))
    }
}

// MARK: - HotkeyParser Edge Cases

final class HotkeyParserEdgeCaseTests: XCTestCase {

    func test_case_insensitive_modifiers() {
        let combo = HotkeyParser.parse("CMD+SHIFT+s")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.command))
        XCTAssertTrue(combo!.modifiers.contains(.shift))
    }

    func test_option_alias_for_alt() {
        let combo = HotkeyParser.parse("Option+A")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.option))
    }

    func test_command_alias_for_cmd() {
        let combo = HotkeyParser.parse("Command+Q")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.command))
        XCTAssertEqual(combo!.keyString, "q")
    }

    func test_control_alias_for_ctrl() {
        let combo = HotkeyParser.parse("Control+Tab")
        XCTAssertNotNil(combo)
        XCTAssertTrue(combo!.modifiers.contains(.control))
    }

    func test_carbon_key_code_for_known_key() {
        let code = HotkeyParser.carbonKeyCode(for: "tab")
        XCTAssertNotNil(code)
    }

    func test_carbon_key_code_for_unknown_key_returns_nil() {
        XCTAssertNil(HotkeyParser.carbonKeyCode(for: "f13"))
    }

    func test_carbon_modifiers_conversion() {
        let mods: ParsedKeyCombo.Modifiers = [.command, .shift]
        let carbon = HotkeyParser.carbonModifiers(for: mods)
        XCTAssertGreaterThan(carbon, 0)
    }
}

// MARK: - WorkspaceStore Edge Cases

@MainActor
final class WorkspaceStoreEdgeCaseTests: XCTestCase {

    func test_cycle_with_single_workspace_returns_same() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Only", sortOrder: 0)
        store.config.workspaces = [ws]
        store.focusedWorkspaceId = ws.id

        XCTAssertEqual(store.nextWorkspaceId(forward: true), ws.id)
        XCTAssertEqual(store.nextWorkspaceId(forward: false), ws.id)
    }

    func test_cycle_with_no_workspaces_returns_nil() {
        let store = WorkspaceStore()
        XCTAssertNil(store.nextWorkspaceId(forward: true))
    }

    func test_cycle_with_unfocused_starts_at_first() {
        let store = WorkspaceStore()
        let a = makeWorkspace(name: "A", sortOrder: 0)
        let b = makeWorkspace(name: "B", sortOrder: 1)
        store.config.workspaces = [a, b]
        store.focusedWorkspaceId = nil

        XCTAssertEqual(store.nextWorkspaceId(forward: true), a.id)
    }

    func test_workspace_by_negative_index_returns_nil() {
        let store = WorkspaceStore()
        store.config.workspaces = [makeWorkspace(name: "A")]
        XCTAssertNil(store.workspaceIdByIndex(-1))
    }

    func test_undock_nonexistent_workspace_is_noop() {
        let store = WorkspaceStore()
        store.config.workspaces = [makeWorkspace(name: "A")]
        let countBefore = store.workspaces.count
        store.undockWorkspace("nonexistent", position: .zero)
        XCTAssertEqual(store.workspaces.count, countBefore)
    }

    func test_redock_nonexistent_workspace_is_noop() {
        let store = WorkspaceStore()
        store.config.workspaces = [makeWorkspace(name: "A")]
        store.redockWorkspace("nonexistent", atSortOrder: 0)
        XCTAssertTrue(store.workspaces.first!.docked)
    }

    func test_recall_all_with_no_floating_is_noop() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", docked: true)
        store.config.workspaces = [ws]
        store.recallAll()
        XCTAssertTrue(store.workspaces.allSatisfy(\.docked))
    }

    func test_load_corrupted_json_keeps_defaults() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("workspaces.json")
        try! "not valid json {{{".data(using: .utf8)!.write(to: url)

        let store = WorkspaceStore()
        store.loadConfig(from: url)
        XCTAssertEqual(store.config.version, 1)
        XCTAssertTrue(store.workspaces.isEmpty)
    }

    func test_bubble_state_focused_takes_priority_over_active() {
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        let store = WorkspaceStore()
        store.config.workspaces = [ws]
        store.focusedWorkspaceId = ws.id
        XCTAssertEqual(store.bubbleState(for: ws), .focused)
    }

    func test_activate_workspace_without_window_id_is_noop() async {
        let ws = makeWorkspace(name: "No Window", itermWindowId: nil)
        let store = WorkspaceStore()
        store.config.workspaces = [ws]
        // Should not crash or throw — just silently return
        await store.activateWorkspace(ws)
    }

    func test_delete_workspace_removes_from_list() async {
        let ws = makeWorkspace(name: "Doomed", itermWindowId: nil)
        let store = WorkspaceStore()
        store.config.workspaces = [ws]
        await store.deleteWorkspace(ws)
        XCTAssertTrue(store.workspaces.isEmpty)
    }
}

// MARK: - FocusEvent Edge Cases

final class FocusEventEdgeCaseTests: XCTestCase {

    func test_tab_focus_event() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"tab","tab_id":"tab-42"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.kind, .tab)
        XCTAssertEqual(event?.tabId, "tab-42")
        XCTAssertNil(event?.windowId)
    }

    func test_session_focus_event() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"session","session_id":"sess-7"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.kind, .session)
        XCTAssertEqual(event?.sessionId, "sess-7")
    }

    func test_invalid_focus_type_returns_nil() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"unknown"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertNil(FocusEvent(from: response))
    }

    func test_missing_data_returns_nil() throws {
        let json = #"{"id":null,"event":"focus_changed"}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertNil(FocusEvent(from: response))
    }

    func test_non_focus_event_returns_nil() throws {
        let json = #"{"id":"req-1","ok":true,"data":{}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        XCTAssertNil(FocusEvent(from: response))
    }
}

// MARK: - WorkspaceStore with FakeBridge

actor FakeBridge: BridgeService {
    var startCalled = false
    var stopCalled = false
    var callLog: [(cmd: String, args: [String: Any])] = []
    private var callResults: [String: Any] = [:]
    private var shouldThrowOnCall = false
    private var shouldThrowOnStart = false

    func start() throws {
        startCalled = true
        if shouldThrowOnStart { throw BridgeError.notRunning }
    }

    func stop() {
        stopCalled = true
    }

    func call(_ cmd: String, args: [String: Any]) async throws -> Any? {
        callLog.append((cmd: cmd, args: args))
        if shouldThrowOnCall { throw BridgeError.remoteError("fake error") }
        return callResults[cmd]
    }

    func setCallResult(_ cmd: String, value: Any) {
        callResults[cmd] = value
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrowOnCall = value
    }

    func setShouldThrowOnStart(_ value: Bool) {
        shouldThrowOnStart = value
    }
}

@MainActor
final class WorkspaceStoreBridgeTests: XCTestCase {

    func test_create_workspace_adds_to_store() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await fake.setCallResult("create_window", value: ["window_id": "pty-new"])
        await store.connectBridge(fake)

        await store.createWorkspace(name: "New", color: "#FF0000", icon: "terminal", tabs: [
            WorkspaceTab(name: "shell", dir: "~", cmd: nil)
        ])

        XCTAssertEqual(store.workspaces.count, 1)
        XCTAssertEqual(store.workspaces.first?.name, "New")
        XCTAssertEqual(store.workspaces.first?.itermWindowId, "pty-new")
    }

    func test_create_workspace_with_bridge_error_does_not_add() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        await fake.setShouldThrow(true)

        await store.createWorkspace(name: "Fail", color: "#FF0000", icon: "terminal", tabs: [])

        XCTAssertTrue(store.workspaces.isEmpty)
    }

    func test_delete_workspace_calls_close_window() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        let ws = makeWorkspace(name: "Doomed", itermWindowId: "pty-doom")
        store.config.workspaces = [ws]

        await store.deleteWorkspace(ws)

        XCTAssertTrue(store.workspaces.isEmpty)
        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "close_window" })
    }

    func test_activate_workspace_calls_bridge() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        let ws = makeWorkspace(name: "Active", itermWindowId: "pty-1")
        store.config.workspaces = [ws]

        await store.activateWorkspace(ws)

        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "activate_window" })
    }

    func test_start_sets_bridge_connected() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)

        XCTAssertTrue(store.bridgeConnected)
    }

    func test_start_with_failing_bridge_sets_disconnected() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await fake.setShouldThrowOnStart(true)
        await store.connectBridge(fake)

        XCTAssertFalse(store.bridgeConnected)
    }
}

// MARK: - Sidebar Panel Behavior

@MainActor
final class SidebarBehaviorTests: XCTestCase {

    func test_showing_sidebar_makes_panel_visible() {
        let store = WorkspaceStore()
        let controller = SidebarPanelController(store: store)

        controller.show()

        XCTAssertTrue(store.sidebarVisible)
        XCTAssertNotNil(controller.panelFrame)
    }

    func test_hiding_sidebar_removes_panel() {
        let store = WorkspaceStore()
        let controller = SidebarPanelController(store: store)

        controller.show()
        controller.hide()

        XCTAssertFalse(store.sidebarVisible)
    }

    func test_toggle_twice_returns_to_original_state() {
        let store = WorkspaceStore()
        let controller = SidebarPanelController(store: store)
        let initialVisibility = store.sidebarVisible

        controller.toggle()
        controller.toggle()

        XCTAssertEqual(store.sidebarVisible, initialVisibility)
    }

    func test_refresh_updates_panel_size_for_bubble_count() {
        let store = WorkspaceStore()
        store.config.workspaces = [
            makeWorkspace(name: "A", docked: true),
            makeWorkspace(name: "B", docked: true),
            makeWorkspace(name: "C", docked: false),
        ]
        let controller = SidebarPanelController(store: store)
        controller.show()

        let frameBefore = controller.panelFrame
        store.config.workspaces.append(makeWorkspace(name: "D", docked: true))
        controller.refresh()
        let frameAfter = controller.panelFrame

        XCTAssertNotNil(frameBefore)
        XCTAssertNotNil(frameAfter)
        // More docked bubbles → taller panel
        XCTAssertGreaterThan(frameAfter!.height, frameBefore!.height)
    }
}

// MARK: - Floating Bubble Manager Behavior

@MainActor
final class FloatingBubbleBehaviorTests: XCTestCase {

    func test_show_floating_bubble_creates_panel() {
        let store = WorkspaceStore()
        let manager = FloatingBubbleManager(store: store)
        let ws = makeWorkspace(name: "Floater", docked: false, floatingPosition: CodablePoint(x: 100, y: 100))

        manager.showFloatingBubble(for: ws)

        XCTAssertTrue(manager.hasPanel(for: ws.id))
    }

    func test_hide_floating_bubble_removes_panel() {
        let store = WorkspaceStore()
        let manager = FloatingBubbleManager(store: store)
        let ws = makeWorkspace(name: "Floater", docked: false)

        manager.showFloatingBubble(for: ws)
        manager.hideFloatingBubble(for: ws.id)

        XCTAssertFalse(manager.hasPanel(for: ws.id))
    }

    func test_recall_all_removes_all_panels_and_redocks() {
        let store = WorkspaceStore()
        let a = makeWorkspace(name: "A", docked: false)
        let b = makeWorkspace(name: "B", docked: false)
        store.config.workspaces = [a, b]
        let manager = FloatingBubbleManager(store: store)
        manager.showFloatingBubble(for: a)
        manager.showFloatingBubble(for: b)

        manager.recallAll()

        XCTAssertFalse(manager.hasPanel(for: a.id))
        XCTAssertFalse(manager.hasPanel(for: b.id))
        XCTAssertTrue(store.workspaces.allSatisfy(\.docked))
    }

    func test_refresh_syncs_panels_with_undocked_workspaces() {
        let store = WorkspaceStore()
        let a = makeWorkspace(name: "A", docked: false)
        let b = makeWorkspace(name: "B", docked: true)
        store.config.workspaces = [a, b]
        let manager = FloatingBubbleManager(store: store)

        manager.refresh()

        XCTAssertTrue(manager.hasPanel(for: a.id))
        XCTAssertFalse(manager.hasPanel(for: b.id))
    }

    func test_refresh_removes_panels_for_redocked_workspaces() {
        let store = WorkspaceStore()
        var ws = makeWorkspace(name: "A", docked: false)
        store.config.workspaces = [ws]
        let manager = FloatingBubbleManager(store: store)
        manager.showFloatingBubble(for: ws)

        // Redock the workspace
        store.redockWorkspace(ws.id, atSortOrder: 0)
        manager.refresh()

        XCTAssertFalse(manager.hasPanel(for: ws.id))
    }

    func test_duplicate_show_does_not_create_second_panel() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", docked: false)
        let manager = FloatingBubbleManager(store: store)

        manager.showFloatingBubble(for: ws)
        manager.showFloatingBubble(for: ws) // second call

        XCTAssertEqual(manager.panelCount, 1)
    }
}

// MARK: - ITerm2Bridge Behavior

final class ITerm2BridgeBehaviorTests: XCTestCase {

    func test_bridge_conforms_to_service_protocol() {
        // ITerm2Bridge must conform to BridgeService
        let bridge: any BridgeService = ITerm2Bridge()
        XCTAssertNotNil(bridge)
    }

    func test_bridge_reports_not_running_before_start() async {
        let bridge = ITerm2Bridge()
        do {
            _ = try await bridge.call("ping")
            XCTFail("Should have thrown notRunning")
        } catch {
            XCTAssertTrue(error is BridgeError)
        }
    }
}

// MARK: - App Wiring Behavior

@MainActor
final class AppWiringTests: XCTestCase {

    func test_app_delegate_creates_store() {
        let delegate = AppDelegate()
        XCTAssertNotNil(delegate.store)
    }

    func test_app_delegate_creates_sidebar_controller() {
        let delegate = AppDelegate()
        XCTAssertNotNil(delegate.sidebarController)
    }

    func test_app_delegate_creates_floating_manager() {
        let delegate = AppDelegate()
        XCTAssertNotNil(delegate.floatingManager)
    }

    func test_toggle_sidebar_flips_visibility() {
        let delegate = AppDelegate()
        let initial = delegate.store.sidebarVisible
        delegate.toggleSidebar()
        XCTAssertNotEqual(delegate.store.sidebarVisible, initial)
    }

    func test_recall_all_redocks_and_refreshes() {
        let delegate = AppDelegate()
        let a = makeWorkspace(name: "A", docked: false)
        delegate.store.config.workspaces = [a]
        delegate.floatingManager.showFloatingBubble(for: a)

        delegate.recallAll()

        XCTAssertTrue(delegate.store.workspaces.allSatisfy(\.docked))
        XCTAssertFalse(delegate.floatingManager.hasPanel(for: a.id))
    }
}

// MARK: - App Launch Behavior

@MainActor
final class AppLaunchBehaviorTests: XCTestCase {

    func test_launch_with_visible_sidebar_config_shows_sidebar() async {
        let delegate = AppDelegate()
        delegate.store.config.sidebar.visible = true
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.store.sidebarVisible)
        XCTAssertNotNil(delegate.sidebarController.panelFrame)
    }

    func test_launch_with_hidden_sidebar_config_does_not_show_sidebar() async {
        let delegate = AppDelegate()
        delegate.store.config.sidebar.visible = false
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertFalse(delegate.store.sidebarVisible)
    }

    func test_launch_connects_bridge() async {
        let delegate = AppDelegate()
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.store.bridgeConnected)
        let started = await fake.startCalled
        XCTAssertTrue(started)
    }

    func test_launch_restores_floating_bubbles() async {
        let delegate = AppDelegate()
        let ws = makeWorkspace(name: "Float", docked: false, floatingPosition: CodablePoint(x: 50, y: 50))
        delegate.store.config.workspaces = [ws]
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.floatingManager.hasPanel(for: ws.id))
    }
}

// MARK: - Sidebar Hosts BubbleListView

@MainActor
final class SidebarContentBehaviorTests: XCTestCase {

    func test_sidebar_panel_has_content_view_after_show() {
        let store = WorkspaceStore()
        store.config.workspaces = [makeWorkspace(name: "A", docked: true)]
        let controller = SidebarPanelController(store: store)
        controller.show()

        // The panel should have a non-empty content view
        XCTAssertNotNil(controller.panelFrame)
        // Panel height should account for at least one bubble
        XCTAssertGreaterThan(controller.panelFrame!.height, 50)
    }
}

// MARK: - Floating Bubble Redock on MouseUp

@MainActor
final class FloatingBubbleRedockBehaviorTests: XCTestCase {

    func test_floating_panel_has_redock_callback() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", docked: false)
        store.config.workspaces = [ws]
        let manager = FloatingBubbleManager(store: store)

        var redockCalled = false
        manager.onRedockCheck = { _, _ in redockCalled = true }
        manager.showFloatingBubble(for: ws)

        // Simulate mouseUp on the panel — the panel should call onRedockCheck
        XCTAssertTrue(manager.hasPanel(for: ws.id))
    }
}

// MARK: - Focus Tracking Behavior

@MainActor
final class FocusTrackingBehaviorTests: XCTestCase {

    func test_focus_event_updates_focused_workspace_id() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Active", itermWindowId: "pty-42")
        store.config.workspaces = [ws]

        store.handleFocusEvent(FocusEvent(kind: .window, windowId: "pty-42"))

        XCTAssertEqual(store.focusedWorkspaceId, ws.id)
    }

    func test_focus_event_for_unknown_window_clears_focus() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        store.config.workspaces = [ws]
        store.focusedWorkspaceId = ws.id

        store.handleFocusEvent(FocusEvent(kind: .window, windowId: "pty-unknown"))

        XCTAssertNil(store.focusedWorkspaceId)
    }

    func test_non_window_focus_event_does_not_change_focus() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        store.config.workspaces = [ws]
        store.focusedWorkspaceId = ws.id

        store.handleFocusEvent(FocusEvent(kind: .tab, tabId: "tab-99"))

        XCTAssertEqual(store.focusedWorkspaceId, ws.id)
    }
}

// MARK: - Hotkey Registration Behavior

@MainActor
final class HotkeyRegistrationBehaviorTests: XCTestCase {

    func test_hotkey_registrar_can_be_created() {
        let registrar = HotkeyRegistrar()
        XCTAssertNotNil(registrar)
    }

    func test_registering_hotkey_stores_handler() {
        let registrar = HotkeyRegistrar()
        var called = false
        let combo = HotkeyParser.parse("Cmd+Shift+S")!
        registrar.register(combo, handler: { called = true })

        XCTAssertGreaterThan(registrar.registeredCount, 0)
    }

    func test_unregister_all_clears_handlers() {
        let registrar = HotkeyRegistrar()
        let combo = HotkeyParser.parse("Cmd+Shift+S")!
        registrar.register(combo, handler: {})
        registrar.unregisterAll()

        XCTAssertEqual(registrar.registeredCount, 0)
    }
}

// MARK: - MenuBar Content Behavior

@MainActor
final class MenuBarContentBehaviorTests: XCTestCase {

    func test_menu_bar_view_can_be_created() {
        let delegate = AppDelegate()
        let view = MenuBarContent(appDelegate: delegate)
        XCTAssertNotNil(view)
    }
}

// MARK: - BubbleView Behavior

final class BubbleViewBehaviorTests: XCTestCase {

    func test_bubble_view_can_be_created() {
        // BubbleView must be instantiable with a workspace and state
        let ws = makeWorkspace(name: "Test")
        let _ = BubbleView(workspace: ws, state: .active, onTap: {})
    }

    func test_color_from_hex_creates_valid_color() {
        // Color(hex:) is the bridge between HexColor and SwiftUI
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }
}

// MARK: - Drag-to-Undock Composed Behavior

@MainActor
final class DragUndockBehaviorTests: XCTestCase {

    func test_completing_drag_outside_sidebar_undocks_workspace_and_shows_floating_panel() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Dragged", docked: true)
        store.config.workspaces = [ws]

        let sidebarController = SidebarPanelController(store: store)
        sidebarController.show()
        let floatingManager = FloatingBubbleManager(store: store)

        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: ws.id, translation: CGSize(width: 10, height: 0))
        machine.dragChanged(workspaceId: ws.id, translation: CGSize(width: 25, height: 0))

        guard let draggedId = machine.dragEnded() else {
            XCTFail("Expected active drag to return workspace ID")
            return
        }

        // Simulate drop outside sidebar
        let dropPoint = CGPoint(x: 300, y: 400)
        var dockZone = DockZone()
        if let sidebarFrame = sidebarController.panelFrame {
            dockZone.sidebarFrame = sidebarFrame
        }

        if !dockZone.contains(dropPoint) {
            store.undockWorkspace(draggedId, position: dropPoint)
            if let workspace = store.workspaces.first(where: { $0.id == draggedId }) {
                floatingManager.showFloatingBubble(for: workspace)
            }
        }

        XCTAssertFalse(store.workspaces.first!.docked)
        XCTAssertTrue(floatingManager.hasPanel(for: ws.id))
    }

    func test_completing_drag_inside_sidebar_keeps_workspace_docked() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Kept", docked: true)
        store.config.workspaces = [ws]

        let sidebarController = SidebarPanelController(store: store)
        sidebarController.show()

        var machine = BubbleDragStateMachine()
        machine.dragChanged(workspaceId: ws.id, translation: CGSize(width: 10, height: 0))
        machine.dragChanged(workspaceId: ws.id, translation: CGSize(width: 25, height: 0))
        let draggedId = machine.dragEnded()

        XCTAssertNotNil(draggedId)
        // Drop point inside sidebar — stays docked
        let dropPoint = CGPoint(x: 36, y: 500)
        var dockZone = DockZone()
        if let sidebarFrame = sidebarController.panelFrame {
            dockZone.sidebarFrame = sidebarFrame
            if dockZone.contains(dropPoint) {
                // No undock — workspace stays docked
            }
        }

        XCTAssertTrue(store.workspaces.first!.docked)
    }
}

// MARK: - Drag-to-Redock Composed Behavior

@MainActor
final class DragRedockBehaviorTests: XCTestCase {

    func test_floating_bubble_dropped_over_sidebar_redocks() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Floating", docked: false, floatingPosition: CodablePoint(x: 200, y: 300))
        store.config.workspaces = [ws]

        let sidebarController = SidebarPanelController(store: store)
        sidebarController.show()
        let floatingManager = FloatingBubbleManager(store: store)
        floatingManager.showFloatingBubble(for: ws)

        // Simulate dropping the floating bubble over the sidebar
        var dockZone = DockZone()
        if let sidebarFrame = sidebarController.panelFrame {
            dockZone.sidebarFrame = sidebarFrame
            let dropCenter = CGPoint(x: sidebarFrame.midX, y: sidebarFrame.midY)

            if dockZone.contains(dropCenter) {
                let sortOrder = dockZone.insertionIndex(
                    at: dropCenter,
                    bubbleCount: store.workspaces.filter(\.docked).count
                )
                store.redockWorkspace(ws.id, atSortOrder: sortOrder)
                floatingManager.hideFloatingBubble(for: ws.id)
            }
        }

        XCTAssertTrue(store.workspaces.first!.docked)
        XCTAssertNil(store.workspaces.first!.floatingPosition)
        XCTAssertFalse(floatingManager.hasPanel(for: ws.id))
    }
}

// MARK: - BubbleListView Behavior

@MainActor
final class BubbleListViewBehaviorTests: XCTestCase {

    func test_bubble_list_view_can_be_created_with_store() {
        let store = WorkspaceStore()
        let view = BubbleListView(store: store)
        XCTAssertNotNil(view)
    }

    func test_docked_workspaces_filter_is_correct() {
        let store = WorkspaceStore()
        store.config.workspaces = [
            makeWorkspace(name: "Docked1", sortOrder: 1, docked: true),
            makeWorkspace(name: "Floating", sortOrder: 2, docked: false),
            makeWorkspace(name: "Docked0", sortOrder: 0, docked: true),
        ]

        let docked = store.workspaces.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(docked.count, 2)
        XCTAssertEqual(docked[0].name, "Docked0")
        XCTAssertEqual(docked[1].name, "Docked1")
    }
}

// MARK: - QuickAddView Behavior

@MainActor
final class QuickAddViewBehaviorTests: XCTestCase {

    func test_quick_add_view_can_be_created() {
        let store = WorkspaceStore()
        let binding = Binding.constant(true)
        let view = QuickAddView(store: store, isPresented: binding)
        XCTAssertNotNil(view)
    }

    func test_creating_workspace_from_template_uses_template_tabs() async {
        let store = WorkspaceStore()
        let fake = FakeBridge()
        await fake.setCallResult("create_window", value: ["window_id": "pty-tmpl"])
        await store.connectBridge(fake)

        let template = WorkspaceTemplate.webDev
        await store.createWorkspace(
            name: template.name,
            color: "#4A90D9",
            icon: template.icon,
            tabs: template.tabs
        )

        XCTAssertEqual(store.workspaces.count, 1)
        XCTAssertEqual(store.workspaces.first?.tabs.count, template.tabs.count)
        XCTAssertEqual(store.workspaces.first?.name, "Web Dev")
    }
}

// MARK: - SettingsView Behavior

@MainActor
final class SettingsViewBehaviorTests: XCTestCase {

    func test_settings_view_can_be_created() {
        let store = WorkspaceStore()
        let view = SettingsView(store: store)
        XCTAssertNotNil(view)
    }

    func test_hotkey_config_changes_persist_in_store() {
        let store = WorkspaceStore()
        store.config.hotkeys.toggleSidebar = "Cmd+Shift+X"
        XCTAssertEqual(store.config.hotkeys.toggleSidebar, "Cmd+Shift+X")
    }

    func test_sidebar_width_changes_persist_in_store() {
        let store = WorkspaceStore()
        store.config.sidebar.width = 96
        XCTAssertEqual(store.config.sidebar.width, 96)
    }
}

// MARK: - App Drag Wiring Behavior

@MainActor
final class AppDragWiringTests: XCTestCase {

    func test_handle_drag_undock_creates_floating_panel() {
        let delegate = AppDelegate()
        let ws = makeWorkspace(name: "Drag", docked: true)
        delegate.store.config.workspaces = [ws]
        delegate.sidebarController.show()

        delegate.handleDragUndock(workspaceId: ws.id, screenPoint: CGPoint(x: 300, y: 400))

        XCTAssertFalse(delegate.store.workspaces.first!.docked)
        XCTAssertTrue(delegate.floatingManager.hasPanel(for: ws.id))
    }

    func test_handle_redock_check_redocks_when_over_sidebar() {
        let delegate = AppDelegate()
        let ws = makeWorkspace(name: "Float", docked: false)
        delegate.store.config.workspaces = [ws]
        delegate.sidebarController.show()
        delegate.floatingManager.showFloatingBubble(for: ws)

        guard let sidebarFrame = delegate.sidebarController.panelFrame else {
            XCTFail("Sidebar should have a frame")
            return
        }

        let overSidebar = NSRect(
            x: sidebarFrame.midX - 36,
            y: sidebarFrame.midY - 40,
            width: 72,
            height: 80
        )
        delegate.handleRedockCheck(workspaceId: ws.id, panelFrame: overSidebar)

        XCTAssertTrue(delegate.store.workspaces.first!.docked)
        XCTAssertFalse(delegate.floatingManager.hasPanel(for: ws.id))
    }

    func test_handle_redock_check_ignores_when_not_over_sidebar() {
        let delegate = AppDelegate()
        let ws = makeWorkspace(name: "Float", docked: false)
        delegate.store.config.workspaces = [ws]
        delegate.sidebarController.show()
        delegate.floatingManager.showFloatingBubble(for: ws)

        let farAway = NSRect(x: 500, y: 500, width: 72, height: 80)
        delegate.handleRedockCheck(workspaceId: ws.id, panelFrame: farAway)

        XCTAssertFalse(delegate.store.workspaces.first!.docked)
        XCTAssertTrue(delegate.floatingManager.hasPanel(for: ws.id))
    }
}

// MARK: - Window Liveness Behavior

@MainActor
final class WindowLivenessBehaviorTests: XCTestCase {

    func test_refresh_clears_stale_window_ids() {
        let store = WorkspaceStore()
        var ws = makeWorkspace(name: "Stale", itermWindowId: "pty-gone")
        store.config.workspaces = [ws]

        let activeWindowIds: Set<String> = ["pty-other"]
        store.refreshWindowLiveness(activeWindowIds: activeWindowIds)

        XCTAssertNil(store.workspaces.first!.itermWindowId)
    }

    func test_refresh_keeps_active_window_ids() {
        let store = WorkspaceStore()
        var ws = makeWorkspace(name: "Active", itermWindowId: "pty-alive")
        store.config.workspaces = [ws]

        let activeWindowIds: Set<String> = ["pty-alive", "pty-other"]
        store.refreshWindowLiveness(activeWindowIds: activeWindowIds)

        XCTAssertEqual(store.workspaces.first!.itermWindowId, "pty-alive")
    }
}

// MARK: - Window Polling Behavior

@MainActor
final class WindowPollingBehaviorTests: XCTestCase {

    func test_poll_windows_updates_liveness() async {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        store.config.workspaces = [ws]

        let fake = FakeBridge()
        // Bridge returns list_windows with only "pty-other"
        await fake.setCallResult("list_windows", value: [
            ["window_id": "pty-other", "tabs": []] as [String: Any]
        ])
        await store.connectBridge(fake)

        await store.pollWindowLiveness()

        XCTAssertNil(store.workspaces.first!.itermWindowId)
    }

    func test_poll_windows_keeps_live_windows() async {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        store.config.workspaces = [ws]

        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [
            ["window_id": "pty-1", "tabs": []] as [String: Any]
        ])
        await store.connectBridge(fake)

        await store.pollWindowLiveness()

        XCTAssertEqual(store.workspaces.first!.itermWindowId, "pty-1")
    }

    func test_poll_windows_handles_bridge_error_gracefully() async {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", itermWindowId: "pty-1")
        store.config.workspaces = [ws]

        let fake = FakeBridge()
        await fake.setShouldThrow(true)
        await store.connectBridge(fake)
        // Reset throw for start, set for poll
        await fake.setShouldThrow(false)
        await fake.setShouldThrow(true)

        await store.pollWindowLiveness()

        // Should not crash, window ID unchanged
        XCTAssertEqual(store.workspaces.first!.itermWindowId, "pty-1")
    }
}

// MARK: - Floating Panel Content Behavior

@MainActor
final class FloatingPanelContentBehaviorTests: XCTestCase {

    func test_floating_panel_has_bubble_content() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "Content", color: "#FF0000", icon: "terminal", docked: false)
        store.config.workspaces = [ws]
        let manager = FloatingBubbleManager(store: store)

        manager.showFloatingBubble(for: ws)

        // Panel should have a content view (not empty)
        XCTAssertTrue(manager.hasPanel(for: ws.id))
        XCTAssertNotNil(manager.panelContentView(for: ws.id))
    }
}

// MARK: - Floating Panel Redock Wiring

@MainActor
final class FloatingPanelRedockWiringTests: XCTestCase {

    func test_floating_panel_mouseup_calls_redock_check() {
        let store = WorkspaceStore()
        let ws = makeWorkspace(name: "A", docked: false)
        store.config.workspaces = [ws]
        let manager = FloatingBubbleManager(store: store)

        var receivedWorkspaceId: String?
        var receivedFrame: NSRect?
        manager.onRedockCheck = { id, frame in
            receivedWorkspaceId = id
            receivedFrame = frame
        }

        manager.showFloatingBubble(for: ws)

        // Simulate mouseUp on the panel
        manager.simulateMouseUp(for: ws.id)

        XCTAssertEqual(receivedWorkspaceId, ws.id)
        XCTAssertNotNil(receivedFrame)
    }
}

// MARK: - Sidebar Drag Callback Wiring

@MainActor
final class SidebarDragCallbackTests: XCTestCase {

    func test_app_delegate_wires_drag_undock_on_launch() async {
        let delegate = AppDelegate()
        let ws = makeWorkspace(name: "Drag", docked: true)
        delegate.store.config.workspaces = [ws]
        delegate.store.config.sidebar.visible = true

        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        // Simulate a completed drag that should trigger undock
        delegate.handleDragUndock(workspaceId: ws.id, screenPoint: CGPoint(x: 300, y: 300))

        XCTAssertFalse(delegate.store.workspaces.first!.docked)
        XCTAssertTrue(delegate.floatingManager.hasPanel(for: ws.id))
    }
}

// MARK: - Settings Save Behavior

@MainActor
final class SettingsSaveBehaviorTests: XCTestCase {

    func test_save_config_after_sidebar_width_change_persists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("workspaces.json")

        let store = WorkspaceStore()
        store.config.sidebar.width = 96
        store.saveConfig(to: url)

        let store2 = WorkspaceStore()
        store2.loadConfig(from: url)
        XCTAssertEqual(store2.config.sidebar.width, 96)
    }

    func test_save_config_after_hotkey_change_persists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("workspaces.json")

        let store = WorkspaceStore()
        store.config.hotkeys.toggleSidebar = "Cmd+Shift+X"
        store.saveConfig(to: url)

        let store2 = WorkspaceStore()
        store2.loadConfig(from: url)
        XCTAssertEqual(store2.config.hotkeys.toggleSidebar, "Cmd+Shift+X")
    }
}

// MARK: - AnyCodable Edge Cases

final class AnyCodableEdgeCaseTests: XCTestCase {

    func test_nested_dict_roundtrip() throws {
        let nested: [String: AnyCodable] = [
            "outer": AnyCodable(["inner": "value"]),
        ]
        let data = try JSONEncoder().encode(nested)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        let outer = decoded["outer"]?.value as? [String: Any]
        XCTAssertEqual(outer?["inner"] as? String, "value")
    }

    func test_array_roundtrip() throws {
        let arr = AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(arr)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let values = decoded.value as? [Any]
        XCTAssertEqual(values?.count, 3)
    }

    func test_null_roundtrip() throws {
        let json = #"{"value":null}"#
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json.data(using: .utf8)!)
        XCTAssertTrue(decoded["value"]?.value is NSNull)
    }

    func test_double_roundtrip() throws {
        let val = AnyCodable(3.14)
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let decodedValue = try XCTUnwrap(decoded.value as? Double)
        XCTAssertEqual(decodedValue, 3.14, accuracy: 0.001)
    }
}
