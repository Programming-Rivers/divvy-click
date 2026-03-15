import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let navigationEngine = NavigationEngine()

    var hotkeyManager: HotkeyManager!
    var overlayController: OverlayWindowController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        // Create the status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Using a system symbol or a simple text
            button.image = NSImage(systemSymbolName: "cursorarrow.and.square.on.square.dashed", accessibilityDescription: "DivvyClick")
            button.title = "⌘"
        }

        // Define menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Divvy-click", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        hotkeyManager = HotkeyManager(engine: navigationEngine)
        overlayController = OverlayWindowController(engine: navigationEngine)

        // Update status button based on engine state
        Publishers.CombineLatest(navigationEngine.$isActive, navigationEngine.$isMouseDown)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive, isMouseDown in
                if isMouseDown {
                    self?.statusItem.button?.title = "• ⌘ ↓"
                } else {
                    self?.statusItem.button?.title = isActive ? "• ⌘ •" : "⌘"
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_: Notification) {
        // Teardown
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
