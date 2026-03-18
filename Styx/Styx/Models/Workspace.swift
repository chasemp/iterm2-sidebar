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

// MARK: - Workspace

struct Workspace: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var color: String
    var icon: String
    var sortOrder: Int
    var itermWindowId: String?
    var asWindowId: Int?      // AppleScript numeric window ID for minimize/restore
    var docked: Bool
    var collapsed: Bool
    var floatingPosition: CodablePoint?
    var tabs: [WorkspaceTab]

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
        tabs: [WorkspaceTab] = []
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
        self.tabs = tabs
    }

    // Support decoding configs saved before collapsed was added
    enum CodingKeys: String, CodingKey {
        case id, name, color, icon, sortOrder, itermWindowId, asWindowId, docked, collapsed, floatingPosition, tabs
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
        tabs = try c.decode([WorkspaceTab].self, forKey: .tabs)
    }
}

// MARK: - WorkspaceTab

struct WorkspaceTab: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var dir: String?
    var cmd: String?
}

// MARK: - Config

struct StyxConfig: Codable {
    var version: Int = 1
    var sidebar: SidebarConfig = SidebarConfig()
    var workspaces: [Workspace] = []
    var hotkeys: HotkeyConfig = HotkeyConfig()
}

struct SidebarConfig: Codable {
    var position: CodablePoint = CodablePoint(x: 0, y: 200)
    var width: CGFloat = 72
    var visible: Bool = true
}

struct HotkeyConfig: Codable {
    var toggleSidebar: String = "Cmd+Shift+S"
    var nextWorkspace: String = "Ctrl+Tab"
    var prevWorkspace: String = "Ctrl+Shift+Tab"
    var nextTab: String = "Ctrl+Alt+Tab"
    var prevTab: String = "Ctrl+Alt+Shift+Tab"
}

// MARK: - Templates

struct WorkspaceTemplate {
    let name: String
    let icon: String
    let tabs: [WorkspaceTab]

    static let webDev = WorkspaceTemplate(
        name: "Web Dev",
        icon: "globe",
        tabs: [
            WorkspaceTab(name: "server", dir: "~/projects", cmd: nil),
            WorkspaceTab(name: "git", dir: "~/projects", cmd: nil),
            WorkspaceTab(name: "editor", dir: "~/projects", cmd: nil),
        ]
    )

    static let devOps = WorkspaceTemplate(
        name: "DevOps",
        icon: "server.rack",
        tabs: [
            WorkspaceTab(name: "ssh-prod", dir: "~", cmd: nil),
            WorkspaceTab(name: "ssh-staging", dir: "~", cmd: nil),
            WorkspaceTab(name: "logs", dir: "~", cmd: nil),
        ]
    )

    static let all: [WorkspaceTemplate] = [webDev, devOps]
}
