import SwiftUI
import AppKit

@main
struct StyxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Styx", systemImage: "square.grid.3x3.topleft.filled") {
            Text("Styx")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WorkspaceStore()
    lazy var sidebarController = SidebarPanelController(store: store)
    lazy var floatingManager = FloatingBubbleManager(store: store)

    func toggleSidebar() {
        sidebarController.toggle()
    }

    func recallAll() {
        floatingManager.recallAll()
        sidebarController.refresh()
    }
}
