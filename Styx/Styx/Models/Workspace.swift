import Foundation

// MARK: - CodablePoint

struct CodablePoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}

// MARK: - Bubble

struct Bubble: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var color: String
    var icon: String
    var sortOrder: Int
    var itermWindowId: String?
    var asWindowId: Int?      // AppleScript numeric window ID for min/restore
    var docked: Bool
    var collapsed: Bool
    var floatingPosition: CodablePoint?
    var homeDir: String?
    var tabs: [BubbleTab]

    init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#4A90D9",
        icon: String = "terminal",
        sortOrder: Int = 0,
        itermWindowId: String? = nil,
        asWindowId: Int? = nil,
        docked: Bool = true,
        collapsed: Bool = false,
        floatingPosition: CodablePoint? = nil,
        homeDir: String? = nil,
        tabs: [BubbleTab] = []
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.itermWindowId = itermWindowId
        self.asWindowId = asWindowId
        self.docked = docked
        self.collapsed = collapsed
        self.floatingPosition = floatingPosition
        self.homeDir = homeDir
        self.tabs = tabs
    }

    // Support decoding configs saved before new fields were added
    enum CodingKeys: String, CodingKey {
        case id, name, color, icon, sortOrder, itermWindowId, asWindowId, docked, collapsed, floatingPosition, homeDir, tabs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        icon = try c.decode(String.self, forKey: .icon)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        itermWindowId = try c.decodeIfPresent(String.self, forKey: .itermWindowId)
        asWindowId = try c.decodeIfPresent(Int.self, forKey: .asWindowId)
        docked = try c.decode(Bool.self, forKey: .docked)
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        floatingPosition = try c.decodeIfPresent(CodablePoint.self, forKey: .floatingPosition)
        homeDir = try c.decodeIfPresent(String.self, forKey: .homeDir)
        tabs = try c.decode([BubbleTab].self, forKey: .tabs)
    }
}

// MARK: - BubbleTab

struct BubbleTab: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var dir: String?
    var cmd: String?
}

// MARK: - Config

struct StyxConfig: Codable {
    var version: Int = 1
    var sidebar: SidebarConfig = SidebarConfig()
    var bubbles: [Bubble] = []
    var hotkeys: HotkeyConfig = HotkeyConfig()
    var terminal: TerminalConfig = TerminalConfig()
}

struct SidebarConfig: Codable {
    var position: CodablePoint = CodablePoint(x: 0, y: 200)
    var width: CGFloat = 72
    var visible: Bool = true
    var showWindowControls: Bool = false
    var bubbleSize: CGFloat = 48
    var opacity: CGFloat = 1.0
}

struct HotkeyConfig: Codable {
    var toggleSidebar: String = "Cmd+Shift+S"
    var nextBubble: String = "Ctrl+Tab"
    var prevBubble: String = "Ctrl+Shift+Tab"
    var nextTab: String = "Ctrl+Alt+Tab"
    var prevTab: String = "Ctrl+Alt+Shift+Tab"
}

struct TerminalConfig: Codable {
    var showBubbleBadge: Bool = false
    var setBubbleEnvVar: Bool = true
}

// MARK: - Templates

struct BubbleTemplate {
    let name: String
    let icon: String
    let tabs: [BubbleTab]

    static let webDev = BubbleTemplate(
        name: "Web Dev",
        icon: "globe",
        tabs: [
            BubbleTab(name: "server", dir: "~/projects", cmd: nil),
            BubbleTab(name: "git", dir: "~/projects", cmd: nil),
            BubbleTab(name: "editor", dir: "~/projects", cmd: nil),
        ]
    )

    static let devOps = BubbleTemplate(
        name: "DevOps",
        icon: "server.rack",
        tabs: [
            BubbleTab(name: "ssh-prod", dir: "~", cmd: nil),
            BubbleTab(name: "ssh-staging", dir: "~", cmd: nil),
            BubbleTab(name: "logs", dir: "~", cmd: nil),
        ]
    )

    static let all: [BubbleTemplate] = [webDev, devOps]
}
