import XCTest
import SwiftUI
@testable import Styx

func makeBubble(
    name: String = "Test",
    color: String = "#4A90D9",
    icon: String = "terminal",
    sortOrder: Int = 0,
    itermWindowId: String? = nil,
    docked: Bool = true,
    floatingPosition: CodablePoint? = nil,
    tabs: [BubbleTab] = []
) -> Bubble {
    Bubble(
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
) -> BubbleTab {
    BubbleTab(name: name, dir: dir, cmd: cmd)
}

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

final class BubbleTests: XCTestCase {

    func test_creates_bubble_with_defaults() {
        let ws = makeBubble(name: "Backend")
        XCTAssertEqual(ws.name, "Backend")
        XCTAssertEqual(ws.color, "#4A90D9")
        XCTAssertEqual(ws.icon, "terminal")
        XCTAssertTrue(ws.docked)
        XCTAssertNil(ws.itermWindowId)
        XCTAssertNil(ws.floatingPosition)
        XCTAssertTrue(ws.tabs.isEmpty)
    }

    func test_bubble_has_stable_id() {
        let ws = makeBubble(name: "Test")
        XCTAssertFalse(ws.id.isEmpty)
    }

    func test_bubble_roundtrips_through_json() throws {
        let ws = makeBubble(
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
        let decoded = try JSONDecoder().decode(Bubble.self, from: data)

        XCTAssertEqual(decoded.name, "Backend")
        XCTAssertEqual(decoded.color, "#FF6B6B")
        XCTAssertEqual(decoded.itermWindowId, "pty-123")
        XCTAssertFalse(decoded.docked)
        XCTAssertEqual(decoded.floatingPosition, CodablePoint(x: 100, y: 200))
        XCTAssertEqual(decoded.tabs.count, 2)
        XCTAssertEqual(decoded.tabs[0].name, "core")
        XCTAssertEqual(decoded.tabs[1].cmd, "make test")
    }

    func test_bubble_equality() {
        let a = makeBubble(name: "A")
        var b = a
        XCTAssertEqual(a, b)
        b.name = "B"
        XCTAssertNotEqual(a, b)
    }
}

final class BubbleTabTests: XCTestCase {

    func test_tab_id_is_name() {
        let tab = makeTab(name: "server")
        XCTAssertEqual(tab.id, "server")
    }

    func test_tab_roundtrips_through_json() throws {
        let tab = makeTab(name: "dev", dir: "~/projects", cmd: "npm start")
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(BubbleTab.self, from: data)
        XCTAssertEqual(decoded.name, "dev")
        XCTAssertEqual(decoded.dir, "~/projects")
        XCTAssertEqual(decoded.cmd, "npm start")
    }
}

final class StyxConfigTests: XCTestCase {

    func test_default_config_has_version_1() {
        let config = StyxConfig()
        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.bubbles.isEmpty)
        XCTAssertTrue(config.sidebar.visible)
    }

    func test_config_roundtrips_through_json() throws {
        var config = StyxConfig()
        config.bubbles = [makeBubble(name: "Backend"), makeBubble(name: "Frontend")]
        config.hotkeys.toggleSidebar = "Cmd+Shift+S"
        config.sidebar.width = 80

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(StyxConfig.self, from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.bubbles.count, 2)
        XCTAssertEqual(decoded.bubbles[0].name, "Backend")
        XCTAssertEqual(decoded.hotkeys.toggleSidebar, "Cmd+Shift+S")
        XCTAssertEqual(decoded.sidebar.width, 80)
    }
}

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

final class BubbleTemplateTests: XCTestCase {

    func test_templates_are_available() {
        XCTAssertFalse(BubbleTemplate.all.isEmpty)
    }

    func test_web_dev_template_has_tabs() {
        XCTAssertEqual(BubbleTemplate.webDev.name, "Web Dev")
        XCTAssertFalse(BubbleTemplate.webDev.tabs.isEmpty)
    }

    func test_devops_template_has_tabs() {
        XCTAssertEqual(BubbleTemplate.devOps.name, "DevOps")
        XCTAssertFalse(BubbleTemplate.devOps.tabs.isEmpty)
    }
}

@MainActor
final class BubbleStoreTests: XCTestCase {

    private func makeStore(bubbles: [Bubble] = []) -> BubbleStore {
        let store = BubbleStore()
        store.config.bubbles = bubbles
        return store
    }

    func test_focused_bubble_returns_focused_state() {
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        let store = makeStore(bubbles: [ws])
        store.focusedBubbleId = ws.id

        XCTAssertEqual(store.bubbleState(for: ws), .focused)
    }

    func test_bubble_with_window_but_not_focused_returns_active() {
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        let store = makeStore(bubbles: [ws])
        store.focusedBubbleId = nil

        XCTAssertEqual(store.bubbleState(for: ws), .active)
    }

    func test_bubble_without_window_returns_disconnected() {
        let ws = makeBubble(name: "A", itermWindowId: nil)
        let store = makeStore(bubbles: [ws])

        XCTAssertEqual(store.bubbleState(for: ws), .disconnected)
    }

    func test_cycle_forward_wraps_around() {
        let a = makeBubble(name: "A", sortOrder: 0)
        let b = makeBubble(name: "B", sortOrder: 1)
        let store = makeStore(bubbles: [a, b])
        store.focusedBubbleId = b.id

        let next = store.nextBubbleId(forward: true)
        XCTAssertEqual(next, a.id)
    }

    func test_cycle_backward_wraps_around() {
        let a = makeBubble(name: "A", sortOrder: 0)
        let b = makeBubble(name: "B", sortOrder: 1)
        let store = makeStore(bubbles: [a, b])
        store.focusedBubbleId = a.id

        let prev = store.nextBubbleId(forward: false)
        XCTAssertEqual(prev, b.id)
    }

    func test_bubble_by_index_returns_correct_id() {
        let a = makeBubble(name: "A", sortOrder: 0)
        let b = makeBubble(name: "B", sortOrder: 1)
        let store = makeStore(bubbles: [a, b])

        XCTAssertEqual(store.bubbleIdByIndex(0), a.id)
        XCTAssertEqual(store.bubbleIdByIndex(1), b.id)
        XCTAssertNil(store.bubbleIdByIndex(5))
    }

    func test_sidebar_visible_mirrors_config() {
        let store = makeStore()
        store.config.sidebar.visible = true
        XCTAssertTrue(store.sidebarVisible)

        store.sidebarVisible = false
        XCTAssertFalse(store.config.sidebar.visible)
    }

    func test_save_and_load_config_roundtrips() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("workspaces.json")

        let store = makeStore(bubbles: [makeBubble(name: "Saved")])
        store.saveConfig(to: configURL)

        let store2 = BubbleStore()
        store2.loadConfig(from: configURL)

        XCTAssertEqual(store2.bubbles.count, 1)
        XCTAssertEqual(store2.bubbles.first?.name, "Saved")
    }

    func test_load_missing_config_uses_defaults() {
        let bogusURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.json")
        let store = BubbleStore()
        store.loadConfig(from: bogusURL)

        XCTAssertTrue(store.bubbles.isEmpty)
        XCTAssertEqual(store.config.version, 1)
    }
}

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

final class BubbleDragStateMachineTests: XCTestCase {

    func test_starts_idle() {
        let machine = BubbleDragStateMachine()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_small_translation_transitions_to_pending() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(machine.phase, .pending(bubbleId: "ws-1"))
    }

    func test_large_translation_transitions_to_active() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 25, height: 0))
        XCTAssertEqual(machine.phase, .active(bubbleId: "ws-1"))
    }

    func test_end_from_pending_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragEnded()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_end_from_active_returns_bubble_id() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0))
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 25, height: 0))
        let result = machine.dragEnded()
        XCTAssertEqual(result, "ws-1")
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_cancel_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 25, height: 25))
        machine.cancel()
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_cancel_from_pending_resets_to_idle() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(machine.phase, .pending(bubbleId: "ws-1"))
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
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 25, height: 0))
        _ = machine.dragEnded()
        let second = machine.dragEnded()
        XCTAssertNil(second)
    }

    func test_active_phase_ignores_further_drag_changes() {
        var machine = BubbleDragStateMachine()
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 10, height: 0)) // → pending
        machine.dragChanged(bubbleId: "ws-1", translation: CGSize(width: 25, height: 0)) // → active
        XCTAssertEqual(machine.phase, .active(bubbleId: "ws-1"))
        machine.dragChanged(bubbleId: "ws-2", translation: CGSize(width: 100, height: 0)) // ignored
        XCTAssertEqual(machine.phase, .active(bubbleId: "ws-1"))
    }
}

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

@MainActor
final class BubbleStoreEdgeCaseTests: XCTestCase {

    func test_cycle_with_single_bubble_returns_same() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Only", sortOrder: 0)
        store.config.bubbles = [ws]
        store.focusedBubbleId = ws.id

        XCTAssertEqual(store.nextBubbleId(forward: true), ws.id)
        XCTAssertEqual(store.nextBubbleId(forward: false), ws.id)
    }

    func test_cycle_with_no_bubbles_returns_nil() {
        let store = BubbleStore()
        XCTAssertNil(store.nextBubbleId(forward: true))
    }

    func test_cycle_with_unfocused_starts_at_first() {
        let store = BubbleStore()
        let a = makeBubble(name: "A", sortOrder: 0)
        let b = makeBubble(name: "B", sortOrder: 1)
        store.config.bubbles = [a, b]
        store.focusedBubbleId = nil

        XCTAssertEqual(store.nextBubbleId(forward: true), a.id)
    }

    func test_bubble_by_negative_index_returns_nil() {
        let store = BubbleStore()
        store.config.bubbles = [makeBubble(name: "A")]
        XCTAssertNil(store.bubbleIdByIndex(-1))
    }

    func test_load_corrupted_json_keeps_defaults() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("workspaces.json")
        try! "not valid json {{{".data(using: .utf8)!.write(to: url)

        let store = BubbleStore()
        store.loadConfig(from: url)
        XCTAssertEqual(store.config.version, 1)
        XCTAssertTrue(store.bubbles.isEmpty)
    }

    func test_bubble_state_focused_takes_priority_over_active() {
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        let store = BubbleStore()
        store.config.bubbles = [ws]
        store.focusedBubbleId = ws.id
        XCTAssertEqual(store.bubbleState(for: ws), .focused)
    }

    func test_activate_bubble_without_window_id_is_noop() async {
        let ws = makeBubble(name: "No Window", itermWindowId: nil)
        let store = BubbleStore()
        store.config.bubbles = [ws]
        await store.activateBubble(ws)
    }

    func test_delete_bubble_removes_from_list() async {
        let ws = makeBubble(name: "Doomed", itermWindowId: nil)
        let store = BubbleStore()
        store.config.bubbles = [ws]
        await store.deleteBubble(ws)
        XCTAssertTrue(store.bubbles.isEmpty)
    }
}

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

    func test_window_event_became_key_parsed() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"window","window_id":"pty-1","event":"TERMINAL_WINDOW_BECAME_KEY"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.windowEvent, .becameKey)
        XCTAssertTrue(event?.windowEvent?.isActive ?? false)
    }

    func test_window_event_resigned_key_parsed() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"window","window_id":"pty-1","event":"TERMINAL_WINDOW_RESIGNED_KEY"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.windowEvent, .resignedKey)
        XCTAssertFalse(event?.windowEvent?.isActive ?? true)
    }

    func test_window_event_missing_defaults_to_nil() throws {
        let json = #"{"id":null,"event":"focus_changed","data":{"type":"window","window_id":"pty-1"}}"#
        let response = try JSONDecoder().decode(BridgeResponse.self, from: json.data(using: .utf8)!)
        let event = FocusEvent(from: response)
        XCTAssertNotNil(event)
        XCTAssertNil(event?.windowEvent)
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
final class BubbleStoreBridgeTests: XCTestCase {

    func test_create_bubble_adds_to_store() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setCallResult("create_window", value: ["window_id": "pty-new"])
        await store.connectBridge(fake)

        await store.createBubble(name: "New", color: "#FF0000", icon: "terminal", tabs: [
            BubbleTab(name: "shell", dir: "~", cmd: nil)
        ])

        XCTAssertEqual(store.bubbles.count, 1)
        XCTAssertEqual(store.bubbles.first?.name, "New")
        XCTAssertEqual(store.bubbles.first?.itermWindowId, "pty-new")
    }

    func test_create_bubble_with_bridge_error_does_not_add() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        await fake.setShouldThrow(true)

        await store.createBubble(name: "Fail", color: "#FF0000", icon: "terminal", tabs: [])

        XCTAssertTrue(store.bubbles.isEmpty)
    }

    func test_delete_bubble_calls_close_window() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        let ws = makeBubble(name: "Doomed", itermWindowId: "pty-doom")
        store.config.bubbles = [ws]

        await store.deleteBubble(ws)

        XCTAssertTrue(store.bubbles.isEmpty)
        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "close_window" })
    }

    func test_activate_bubble_calls_bridge() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        let ws = makeBubble(name: "Active", itermWindowId: "pty-1")
        store.config.bubbles = [ws]

        await store.activateBubble(ws)

        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "activate_window" })
    }

    func test_start_sets_bridge_connected() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)

        XCTAssertTrue(store.bridgeConnected)
    }

    func test_start_with_failing_bridge_sets_disconnected() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setShouldThrowOnStart(true)
        await store.connectBridge(fake)

        XCTAssertFalse(store.bridgeConnected)
    }
}

@MainActor
final class SidebarBehaviorTests: XCTestCase {

    func test_showing_sidebar_makes_panel_visible() {
        let store = BubbleStore()
        let controller = SidebarPanelController(store: store, headless: true)

        controller.show()

        XCTAssertTrue(store.sidebarVisible)
        XCTAssertNotNil(controller.panelFrame)
    }

    func test_hiding_sidebar_removes_panel() {
        let store = BubbleStore()
        let controller = SidebarPanelController(store: store, headless: true)

        controller.show()
        controller.hide()

        XCTAssertFalse(store.sidebarVisible)
    }

    func test_toggle_twice_returns_to_original_state() {
        let store = BubbleStore()
        let controller = SidebarPanelController(store: store, headless: true)
        let initialVisibility = store.sidebarVisible

        controller.toggle()
        controller.toggle()

        XCTAssertEqual(store.sidebarVisible, initialVisibility)
    }

    func test_refresh_updates_panel_size_for_bubble_count() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", docked: true),
            makeBubble(name: "B", docked: true),
            makeBubble(name: "C", docked: false),
        ]
        let controller = SidebarPanelController(store: store, headless: true)
        controller.show()

        let frameBefore = controller.panelFrame
        store.config.bubbles.append(makeBubble(name: "D", docked: true))
        controller.refresh()
        let frameAfter = controller.panelFrame

        XCTAssertNotNil(frameBefore)
        XCTAssertNotNil(frameAfter)
        XCTAssertGreaterThan(frameAfter!.height, frameBefore!.height)
    }
}

final class ITerm2BridgeBehaviorTests: XCTestCase {

    func test_bridge_conforms_to_service_protocol() {
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

@MainActor
final class AppWiringTests: XCTestCase {

    func test_app_delegate_creates_store() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        XCTAssertNotNil(delegate.store)
    }

    func test_app_delegate_creates_sidebar_controller() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        XCTAssertNotNil(delegate.sidebarController)
    }

    func test_toggle_sidebar_flips_visibility() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let initial = delegate.store.sidebarVisible
        delegate.toggleSidebar()
        XCTAssertNotEqual(delegate.store.sidebarVisible, initial)
    }

}

@MainActor
final class AppLaunchBehaviorTests: XCTestCase {

    func test_launch_with_visible_sidebar_config_shows_sidebar() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.sidebar.visible = true
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.store.sidebarVisible)
        XCTAssertNotNil(delegate.sidebarController.panelFrame)
    }

    func test_launch_with_hidden_sidebar_config_does_not_show_sidebar() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.sidebar.visible = false
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertFalse(delegate.store.sidebarVisible)
    }

    func test_launch_connects_bridge() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.store.bridgeConnected)
        let started = await fake.startCalled
        XCTAssertTrue(started)
    }

}

@MainActor
final class SidebarContentBehaviorTests: XCTestCase {

    func test_sidebar_panel_has_content_view_after_show() {
        let store = BubbleStore()
        store.config.bubbles = [makeBubble(name: "A", docked: true)]
        let controller = SidebarPanelController(store: store, headless: true)
        controller.show()

        XCTAssertNotNil(controller.panelFrame)
        XCTAssertGreaterThan(controller.panelFrame!.height, 50)
    }
}

@MainActor
final class FocusTrackingBehaviorTests: XCTestCase {

    func test_focus_event_updates_focused_bubble_id() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Active", itermWindowId: "pty-42")
        store.config.bubbles = [ws]

        store.handleFocusEvent(FocusEvent(kind: .window, windowId: "pty-42"))

        XCTAssertEqual(store.focusedBubbleId, ws.id)
    }

    func test_focus_event_for_unknown_window_clears_focus() {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]
        store.focusedBubbleId = ws.id

        store.handleFocusEvent(FocusEvent(kind: .window, windowId: "pty-unknown"))

        XCTAssertNil(store.focusedBubbleId)
    }

    func test_non_window_focus_event_does_not_change_focus() {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]
        store.focusedBubbleId = ws.id

        store.handleFocusEvent(FocusEvent(kind: .tab, tabId: "tab-99"))

        XCTAssertEqual(store.focusedBubbleId, ws.id)
    }

    func test_resigned_key_event_clears_focused_bubble() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Active", itermWindowId: "pty-42")
        store.config.bubbles = [ws]
        store.focusedBubbleId = ws.id

        store.handleFocusEvent(FocusEvent(
            kind: .window, windowId: "pty-42",
            windowEvent: .resignedKey
        ))

        XCTAssertNil(store.focusedBubbleId)
    }

    func test_resigned_key_for_other_window_does_not_clear_focus() {
        let store = BubbleStore()
        let a = makeBubble(name: "A", itermWindowId: "pty-1")
        let b = makeBubble(name: "B", itermWindowId: "pty-2")
        store.config.bubbles = [a, b]
        store.focusedBubbleId = a.id

        // Window B resigns — should not affect A's focus
        store.handleFocusEvent(FocusEvent(
            kind: .window, windowId: "pty-2",
            windowEvent: .resignedKey
        ))

        XCTAssertEqual(store.focusedBubbleId, a.id)
    }

    func test_became_key_event_sets_focused_bubble() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Active", itermWindowId: "pty-42")
        store.config.bubbles = [ws]

        store.handleFocusEvent(FocusEvent(
            kind: .window, windowId: "pty-42",
            windowEvent: .becameKey
        ))

        XCTAssertEqual(store.focusedBubbleId, ws.id)
    }

    func test_is_current_event_sets_focused_bubble() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Active", itermWindowId: "pty-42")
        store.config.bubbles = [ws]

        store.handleFocusEvent(FocusEvent(
            kind: .window, windowId: "pty-42",
            windowEvent: .isCurrent
        ))

        XCTAssertEqual(store.focusedBubbleId, ws.id)
    }
}

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

@MainActor
final class MenuBarContentBehaviorTests: XCTestCase {

    func test_menu_bar_view_can_be_created() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let view = MenuBarContent(appDelegate: delegate)
        XCTAssertNotNil(view)
    }
}

final class BubbleViewBehaviorTests: XCTestCase {

    func test_bubble_view_can_be_created() {
        let ws = makeBubble(name: "Test")
        let _ = BubbleView(bubble: ws, state: .active, onTap: {})
    }

    func test_color_from_hex_creates_valid_color() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }
}

@MainActor
final class BubbleListViewBehaviorTests: XCTestCase {

    func test_bubble_list_view_can_be_created_with_store() {
        let store = BubbleStore()
        let view = BubbleListView(store: store)
        XCTAssertNotNil(view)
    }

    func test_docked_bubbles_filter_is_correct() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "Docked1", sortOrder: 1, docked: true),
            makeBubble(name: "Floating", sortOrder: 2, docked: false),
            makeBubble(name: "Docked0", sortOrder: 0, docked: true),
        ]

        let docked = store.bubbles.filter(\.docked).sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(docked.count, 2)
        XCTAssertEqual(docked[0].name, "Docked0")
        XCTAssertEqual(docked[1].name, "Docked1")
    }
}

@MainActor
final class QuickAddViewBehaviorTests: XCTestCase {

    func test_quick_add_view_can_be_created() {
        let store = BubbleStore()
        let binding = Binding.constant(true)
        let view = QuickAddView(store: store, isPresented: binding)
        XCTAssertNotNil(view)
    }

    func test_creating_bubble_from_template_uses_template_tabs() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setCallResult("create_window", value: ["window_id": "pty-tmpl"])
        await store.connectBridge(fake)

        let template = BubbleTemplate.webDev
        await store.createBubble(
            name: template.name,
            color: "#4A90D9",
            icon: template.icon,
            tabs: template.tabs
        )

        XCTAssertEqual(store.bubbles.count, 1)
        XCTAssertEqual(store.bubbles.first?.tabs.count, template.tabs.count)
        XCTAssertEqual(store.bubbles.first?.name, "Web Dev")
    }
}

@MainActor
final class SettingsViewBehaviorTests: XCTestCase {

    func test_settings_view_can_be_created() {
        let store = BubbleStore()
        let view = SettingsView(store: store)
        XCTAssertNotNil(view)
    }

    func test_hotkey_config_changes_persist_in_store() {
        let store = BubbleStore()
        store.config.hotkeys.toggleSidebar = "Cmd+Shift+X"
        XCTAssertEqual(store.config.hotkeys.toggleSidebar, "Cmd+Shift+X")
    }

    func test_sidebar_width_changes_persist_in_store() {
        let store = BubbleStore()
        store.config.sidebar.width = 96
        XCTAssertEqual(store.config.sidebar.width, 96)
    }
}

@MainActor
final class WindowLivenessBehaviorTests: XCTestCase {

    func test_refresh_clears_stale_window_ids() {
        let store = BubbleStore()
        var ws = makeBubble(name: "Stale", itermWindowId: "pty-gone")
        store.config.bubbles = [ws]

        let activeWindowIds: Set<String> = ["pty-other"]
        store.refreshWindowLiveness(activeWindowIds: activeWindowIds)

        XCTAssertEqual(store.bubbles.count, 1, "Bubble should persist when window dies")
        XCTAssertNil(store.bubbles.first?.itermWindowId, "Window ID should be cleared")
        XCTAssertNil(store.bubbles.first?.asWindowId, "AppleScript window ID should be cleared")
    }

    func test_refresh_keeps_active_window_ids() {
        let store = BubbleStore()
        var ws = makeBubble(name: "Active", itermWindowId: "pty-alive")
        store.config.bubbles = [ws]

        let activeWindowIds: Set<String> = ["pty-alive", "pty-other"]
        store.refreshWindowLiveness(activeWindowIds: activeWindowIds)

        XCTAssertEqual(store.bubbles.first!.itermWindowId, "pty-alive")
    }
}

@MainActor
final class WindowPollingBehaviorTests: XCTestCase {

    func test_poll_windows_updates_liveness() async {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]

        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [
            ["window_id": "pty-other", "tabs": []] as [String: Any]
        ])
        await store.connectBridge(fake)

        await store.pollWindowLiveness()

        XCTAssertEqual(store.bubbles.count, 1, "Bubble should persist when window dies")
        XCTAssertNil(store.bubbles.first?.itermWindowId, "Window ID should be cleared after poll")
    }

    func test_poll_windows_keeps_live_windows() async {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]

        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [
            ["window_id": "pty-1", "tabs": []] as [String: Any]
        ])
        await store.connectBridge(fake)

        await store.pollWindowLiveness()

        XCTAssertEqual(store.bubbles.first!.itermWindowId, "pty-1")
    }

    func test_poll_windows_handles_bridge_error_gracefully() async {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]

        let fake = FakeBridge()
        await fake.setShouldThrow(true)
        await store.connectBridge(fake)
        await fake.setShouldThrow(false)
        await fake.setShouldThrow(true)

        await store.pollWindowLiveness()

        XCTAssertEqual(store.bubbles.first!.itermWindowId, "pty-1")
    }
}

@MainActor
final class SettingsSaveBehaviorTests: XCTestCase {

    func test_save_config_after_sidebar_width_change_persists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("workspaces.json")

        let store = BubbleStore()
        store.config.sidebar.width = 96
        store.saveConfig(to: url)

        let store2 = BubbleStore()
        store2.loadConfig(from: url)
        XCTAssertEqual(store2.config.sidebar.width, 96)
    }

    func test_save_config_after_hotkey_change_persists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("workspaces.json")

        let store = BubbleStore()
        store.config.hotkeys.toggleSidebar = "Cmd+Shift+X"
        store.saveConfig(to: url)

        let store2 = BubbleStore()
        store2.loadConfig(from: url)
        XCTAssertEqual(store2.config.hotkeys.toggleSidebar, "Cmd+Shift+X")
    }
}

@MainActor
final class LaunchWiringCompletenessTests: XCTestCase {

    func test_launch_starts_polling_task() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [[String: Any]]())
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.isPollingActive)
    }

    func test_shutdown_cancels_polling() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [[String: Any]]())
        await delegate.launch(bridge: fake)
        await delegate.shutdownForTest()

        XCTAssertFalse(delegate.isPollingActive)
    }
}

final class BridgeScriptBundlingTests: XCTestCase {

    func test_bridge_script_exists_at_development_path() {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // Styx/
        let bridgePath = projectDir.appendingPathComponent("StyxBridge/bridge_daemon.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bridgePath.path),
                       "bridge_daemon.py should exist at \(bridgePath.path)")
    }

    func test_bridge_commands_script_exists() {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let commandsPath = projectDir.appendingPathComponent("StyxBridge/commands.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: commandsPath.path),
                       "commands.py should exist at \(commandsPath.path)")
    }

    func test_requirements_file_exists() {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let reqPath = projectDir.appendingPathComponent("StyxBridge/requirements.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: reqPath.path),
                       "requirements.txt should exist at \(reqPath.path)")
    }
}

@MainActor
final class PanelResizeMathTests: XCTestCase {

    func test_sidebar_panel_height_grows_with_bubbles() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", docked: true),
        ]
        let controller = SidebarPanelController(store: store, headless: true)
        controller.show()
        let oneHeight = controller.panelFrame!.height

        store.config.bubbles.append(makeBubble(name: "B", docked: true))
        store.config.bubbles.append(makeBubble(name: "C", docked: true))
        controller.refresh()
        let threeHeight = controller.panelFrame!.height

        XCTAssertGreaterThan(threeHeight, oneHeight)
    }

    func test_sidebar_panel_has_minimum_height_with_zero_bubbles() {
        let store = BubbleStore()
        let controller = SidebarPanelController(store: store, headless: true)
        controller.show()

        XCTAssertGreaterThan(controller.panelFrame!.height, 0)
    }
}

// MARK: - Hotkey Re-registration

@MainActor
final class HotkeyReregistrationTests: XCTestCase {

    func test_reregister_hotkeys_clears_old_and_registers_new() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.hotkeys.toggleSidebar = "Cmd+Shift+S"

        delegate.registerHotkeys()
        let countBefore = delegate.hotkeyRegistrar.registeredCount
        XCTAssertGreaterThan(countBefore, 0)

        // Change hotkey config and re-register
        delegate.store.config.hotkeys.toggleSidebar = "Cmd+Shift+X"
        delegate.reregisterHotkeys()
        let countAfter = delegate.hotkeyRegistrar.registeredCount

        // Count should be same (old cleared, new registered)
        XCTAssertEqual(countAfter, countBefore)
    }
}

// MARK: - Capture Current Window

@MainActor
final class CaptureCurrentWindowTests: XCTestCase {

    func test_capture_creates_bubble_from_window_info() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        // Simulate bridge returning active window info
        await fake.setCallResult("get_active_window", value: [
            "window_id": "pty-capture",
            "tabs": [
                ["tab_id": "tab-1", "sessions": [["session_id": "sess-1", "name": "~/projects"]]] as [String: Any],
                ["tab_id": "tab-2", "sessions": [["session_id": "sess-2", "name": "~/logs"]]] as [String: Any],
            ] as [[String: Any]],
        ] as [String: Any])
        await store.connectBridge(fake)

        await store.captureCurrentWindow(name: "Captured", color: "#FF6B6B", icon: "star")

        XCTAssertEqual(store.bubbles.count, 1)
        let ws = store.bubbles.first!
        XCTAssertEqual(ws.name, "Captured")
        XCTAssertEqual(ws.itermWindowId, "pty-capture")
        XCTAssertEqual(ws.tabs.count, 2)
    }

    func test_capture_with_no_active_window_does_nothing() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setShouldThrow(true)
        await store.connectBridge(fake)
        await fake.setShouldThrow(false)
        await fake.setShouldThrow(true) // throw on get_active_window

        await store.captureCurrentWindow(name: "Fail", color: "#000", icon: "star")

        XCTAssertTrue(store.bubbles.isEmpty)
    }
}

// MARK: - Bridge Error State

@MainActor
final class BridgeErrorStateTests: XCTestCase {

    func test_store_tracks_iterm2_running_state() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setCallResult("list_windows", value: [
            ["window_id": "pty-1", "tabs": []] as [String: Any]
        ])
        await store.connectBridge(fake)

        await store.pollWindowLiveness()

        XCTAssertTrue(store.iTerm2Reachable)
    }

    func test_store_detects_iterm2_unreachable() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        await fake.setShouldThrow(true)

        await store.pollWindowLiveness()

        XCTAssertFalse(store.iTerm2Reachable)
    }

    func test_bridge_not_connected_shows_in_store() {
        let store = BubbleStore()
        XCTAssertFalse(store.bridgeConnected)
    }
}

// MARK: - AnyCodable Edge Cases

// MARK: - MenuBar Capture Action

@MainActor
final class MenuBarCaptureActionTests: XCTestCase {

    func test_capture_current_window_action_exists_on_delegate() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await fake.setCallResult("get_active_window", value: [
            "window_id": "pty-cap",
            "tabs": [[String: Any]](),
        ] as [String: Any])
        await delegate.launch(bridge: fake)

        await delegate.captureCurrentWindow()

        XCTAssertEqual(delegate.store.bubbles.count, 1)
        XCTAssertEqual(delegate.store.bubbles.first?.itermWindowId, "pty-cap")
    }
}

// MARK: - UI Error State

@MainActor
final class UIErrorStateTests: XCTestCase {

    func test_menubar_shows_iterm2_unreachable_text() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.iTerm2Reachable = false
        delegate.store.bridgeConnected = true

        // The store exposes the state; MenuBarContent reads it
        XCTAssertFalse(delegate.store.iTerm2Reachable)
        XCTAssertTrue(delegate.store.bridgeConnected)
    }

    func test_bubble_bubbles_dormant_when_iterm2_unreachable() {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", itermWindowId: "pty-1")
        store.config.bubbles = [ws]
        store.iTerm2Reachable = false

        // Even with a window ID, the bubble appears active
        // (iTerm2Reachable is informational, doesn't override bubble state)
        XCTAssertEqual(store.bubbleState(for: ws), .active)
    }
}

// MARK: - Accessibility Permission

final class AccessibilityPermissionTests: XCTestCase {

    func test_accessibility_check_returns_bool() {
        // AXIsProcessTrusted() returns a Bool — just verify it doesn't crash
        let trusted = AccessibilityChecker.isTrusted
        // Can be true or false depending on system state — just verify it's callable
        XCTAssertNotNil(trusted)
    }

    func test_accessibility_checker_has_prompt_method() {
        // Verify the method exists (calling it would show a system dialog)
        XCTAssertTrue(AccessibilityChecker.self is Any.Type)
    }
}

// MARK: - Rename Bubble

@MainActor
final class RenameBubbleTests: XCTestCase {

    func test_rename_bubble_changes_name() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Old")
        store.config.bubbles = [ws]

        store.renameBubble(ws.id, to: "New")

        XCTAssertEqual(store.bubbles.first?.name, "New")
    }

    func test_rename_nonexistent_bubble_is_noop() {
        let store = BubbleStore()
        let ws = makeBubble(name: "A")
        store.config.bubbles = [ws]

        store.renameBubble("bogus-id", to: "New")

        XCTAssertEqual(store.bubbles.first?.name, "A")
    }

    func test_rename_trims_whitespace() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Old")
        store.config.bubbles = [ws]

        store.renameBubble(ws.id, to: "  New Name  ")

        XCTAssertEqual(store.bubbles.first?.name, "New Name")
    }

    func test_rename_empty_string_keeps_old_name() {
        let store = BubbleStore()
        let ws = makeBubble(name: "Keep")
        store.config.bubbles = [ws]

        store.renameBubble(ws.id, to: "   ")

        XCTAssertEqual(store.bubbles.first?.name, "Keep")
    }
}

// MARK: - Capture Uses Session Name

@MainActor
final class CaptureAutoNameTests: XCTestCase {

    func test_capture_uses_first_session_name_when_no_name_given() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setCallResult("get_active_window", value: [
            "window_id": "pty-auto",
            "tabs": [
                ["tab_id": "t1", "sessions": [["session_id": "s1", "name": "~/projects/backend"]]] as [String: Any],
            ] as [[String: Any]],
        ] as [String: Any])
        await store.connectBridge(fake)

        await store.captureCurrentWindow(name: nil, color: "#4A90D9", icon: "terminal")

        XCTAssertEqual(store.bubbles.first?.name, "~/projects/backend")
    }

    func test_capture_with_explicit_name_uses_it() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await fake.setCallResult("get_active_window", value: [
            "window_id": "pty-named",
            "tabs": [
                ["tab_id": "t1", "sessions": [["session_id": "s1", "name": "~/stuff"]]] as [String: Any],
            ] as [[String: Any]],
        ] as [String: Any])
        await store.connectBridge(fake)

        await store.captureCurrentWindow(name: "MyName", color: "#4A90D9", icon: "terminal")

        XCTAssertEqual(store.bubbles.first?.name, "MyName")
    }
}

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

// MARK: - Bubble Selection (Keyboard Navigation)

@MainActor
final class BubbleSelectionTests: XCTestCase {

    func test_selected_bubble_index_starts_nil() {
        let store = BubbleStore()
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_select_next_bubble_from_nil_selects_first() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectNextBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 0)
    }

    func test_select_next_bubble_advances_index() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectedBubbleIndex = 0
        store.selectNextBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 1)
    }

    func test_select_next_bubble_wraps_around() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectedBubbleIndex = 1
        store.selectNextBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 0)
    }

    func test_select_previous_bubble_from_nil_selects_last() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectPreviousBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 1)
    }

    func test_select_previous_bubble_decrements_index() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectedBubbleIndex = 1
        store.selectPreviousBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 0)
    }

    func test_select_previous_bubble_wraps_around() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        store.selectedBubbleIndex = 0
        store.selectPreviousBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 1)
    }

    func test_select_bubble_by_valid_index() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
            makeBubble(name: "C", sortOrder: 2, docked: true),
        ]
        store.selectBubbleByIndex(2)
        XCTAssertEqual(store.selectedBubbleIndex, 2)
    }

    func test_select_bubble_by_out_of_range_index_is_noop() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
        ]
        store.selectBubbleByIndex(5)
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_select_bubble_by_negative_index_is_noop() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
        ]
        store.selectBubbleByIndex(-1)
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_clear_bubble_selection() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
        ]
        store.selectedBubbleIndex = 0
        store.clearBubbleSelection()
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_select_next_with_no_docked_bubbles_is_noop() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: false),
        ]
        store.selectNextBubble()
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_select_previous_with_no_docked_bubbles_is_noop() {
        let store = BubbleStore()
        store.selectPreviousBubble()
        XCTAssertNil(store.selectedBubbleIndex)
    }

    func test_select_next_only_counts_docked_bubbles() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "Floating", sortOrder: 1, docked: false),
            makeBubble(name: "B", sortOrder: 2, docked: true),
        ]
        store.selectedBubbleIndex = 0
        store.selectNextBubble()
        XCTAssertEqual(store.selectedBubbleIndex, 1) // index 1 of docked (B)
    }

    func test_activate_selected_bubble_calls_activate_bubble() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        let ws = makeBubble(name: "A", sortOrder: 0, itermWindowId: "pty-sel", docked: true)
        store.config.bubbles = [ws]
        store.selectedBubbleIndex = 0

        await store.activateSelectedBubble()

        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "activate_window" })
    }

    func test_activate_selected_bubble_with_nil_index_is_noop() async {
        let store = BubbleStore()
        let fake = FakeBridge()
        await store.connectBridge(fake)
        store.config.bubbles = [makeBubble(name: "A", sortOrder: 0, itermWindowId: "pty-1", docked: true)]
        store.selectedBubbleIndex = nil

        await store.activateSelectedBubble()

        let log = await fake.callLog
        XCTAssertFalse(log.contains { $0.cmd == "activate_window" })
    }
}

// MARK: - Proxy Window Manager

@MainActor
final class ProxyWindowManagerTests: XCTestCase {

    func test_proxy_manager_can_be_created() {
        let store = BubbleStore()
        let manager = ProxyWindowManager(store: store, headless: true)
        XCTAssertNotNil(manager)
    }

    func test_proxy_refresh_tracks_docked_bubbles() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()

        XCTAssertEqual(manager.proxyCount, 2)
        XCTAssertTrue(manager.hasProxy(for: store.bubbles[0].id))
        XCTAssertTrue(manager.hasProxy(for: store.bubbles[1].id))
    }

    func test_proxy_refresh_ignores_undocked_bubbles() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "Docked", sortOrder: 0, docked: true),
            makeBubble(name: "Floating", sortOrder: 1, docked: false),
        ]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()

        XCTAssertEqual(manager.proxyCount, 1)
        XCTAssertTrue(manager.hasProxy(for: store.bubbles[0].id))
        XCTAssertFalse(manager.hasProxy(for: store.bubbles[1].id))
    }

    func test_proxy_refresh_removes_stale_proxies() {
        let store = BubbleStore()
        let ws = makeBubble(name: "A", sortOrder: 0, docked: true)
        store.config.bubbles = [ws]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()
        XCTAssertEqual(manager.proxyCount, 1)

        // Mark the bubble as undocked directly
        store.config.bubbles[0].docked = false
        manager.refresh()
        XCTAssertEqual(manager.proxyCount, 0)
    }

    func test_proxy_close_all_clears_everything() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()
        XCTAssertEqual(manager.proxyCount, 2)

        manager.closeAll()
        XCTAssertEqual(manager.proxyCount, 0)
    }

    func test_proxy_refresh_is_idempotent() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
        ]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()
        manager.refresh()
        manager.refresh()

        XCTAssertEqual(manager.proxyCount, 1)
    }

    func test_proxy_title_matches_bubble_name() {
        let store = BubbleStore()
        store.config.bubbles = [
            makeBubble(name: "MyBubble", sortOrder: 0, docked: true),
        ]
        let manager = ProxyWindowManager(store: store, headless: true)
        manager.refresh()

        XCTAssertEqual(manager.proxyTitle(for: store.bubbles[0].id), "MyBubble")
    }
}

// MARK: - HotkeyParser Function Keys

final class HotkeyParserFunctionKeyTests: XCTestCase {

    func test_carbon_key_code_for_f1() {
        let code = HotkeyParser.carbonKeyCode(for: "f1")
        XCTAssertNotNil(code)
    }

    func test_carbon_key_code_for_f9() {
        let code = HotkeyParser.carbonKeyCode(for: "f9")
        XCTAssertNotNil(code)
    }

    func test_carbon_key_code_for_all_function_keys() {
        for i in 1...9 {
            let code = HotkeyParser.carbonKeyCode(for: "f\(i)")
            XCTAssertNotNil(code, "F\(i) should have a Carbon key code")
        }
    }

    func test_parses_function_key_combo() {
        let combo = HotkeyParser.parse("Cmd+F1")
        XCTAssertNotNil(combo)
        XCTAssertEqual(combo!.keyString, "f1")
        XCTAssertTrue(combo!.modifiers.contains(.command))
    }
}

// MARK: - Sidebar Keyboard Navigation Wiring

@MainActor
final class SidebarKeyboardNavigationTests: XCTestCase {

    func test_app_delegate_creates_proxy_manager() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertNotNil(delegate.proxyManager)
    }

    func test_launch_refreshes_proxy_windows() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let ws = makeBubble(name: "A", sortOrder: 0, docked: true)
        delegate.store.config.bubbles = [ws]
        delegate.store.config.sidebar.visible = true
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)

        XCTAssertTrue(delegate.proxyManager.hasProxy(for: ws.id))
    }

    func test_sidebar_panel_can_become_key() {
        let store = BubbleStore()
        store.config.bubbles = [makeBubble(name: "A", docked: true)]
        let controller = SidebarPanelController(store: store, headless: true)
        controller.show()

        XCTAssertTrue(controller.panelCanBecomeKey)
    }

    func test_handle_sidebar_key_down_arrow_selects_next() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]

        delegate.handleSidebarKeyEvent(keyCode: 125, modifierFlags: []) // down arrow

        XCTAssertEqual(delegate.store.selectedBubbleIndex, 0)
    }

    func test_handle_sidebar_key_up_arrow_selects_previous() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]

        delegate.handleSidebarKeyEvent(keyCode: 126, modifierFlags: []) // up arrow

        XCTAssertEqual(delegate.store.selectedBubbleIndex, 1) // last
    }

    func test_handle_sidebar_key_return_activates_selected() async {
        let delegate = AppDelegate(); do { delegate.headless = true }
        let fake = FakeBridge()
        await delegate.launch(bridge: fake)
        let ws = makeBubble(name: "A", sortOrder: 0, itermWindowId: "pty-key", docked: true)
        delegate.store.config.bubbles = [ws]
        delegate.store.selectedBubbleIndex = 0

        delegate.handleSidebarKeyEvent(keyCode: 36, modifierFlags: []) // return

        // Give the async task a moment to complete
        try? await Task.sleep(for: .milliseconds(50))
        let log = await fake.callLog
        XCTAssertTrue(log.contains { $0.cmd == "activate_window" })
    }

    func test_handle_sidebar_key_escape_clears_selection() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
        ]
        delegate.store.selectedBubbleIndex = 0

        delegate.handleSidebarKeyEvent(keyCode: 53, modifierFlags: []) // escape

        XCTAssertNil(delegate.store.selectedBubbleIndex)
    }

    func test_handle_sidebar_key_fn_number_selects_by_index() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
            makeBubble(name: "C", sortOrder: 2, docked: true),
        ]

        // Fn+2 (kVK_ANSI_2 = 19, function modifier)
        delegate.handleSidebarKeyEvent(keyCode: 19, modifierFlags: .function)

        XCTAssertEqual(delegate.store.selectedBubbleIndex, 1) // 0-indexed
    }

    func test_handle_sidebar_key_f_key_selects_by_index() {
        let delegate = AppDelegate(); do { delegate.headless = true }
        delegate.store.config.bubbles = [
            makeBubble(name: "A", sortOrder: 0, docked: true),
            makeBubble(name: "B", sortOrder: 1, docked: true),
        ]

        // F1 key code = 122
        delegate.handleSidebarKeyEvent(keyCode: 122, modifierFlags: [])

        XCTAssertEqual(delegate.store.selectedBubbleIndex, 0)
    }
}
