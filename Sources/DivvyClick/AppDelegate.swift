import AppKit
import SwiftUI
import Combine

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    public override init() {
        super.init()
    }
    var statusItem: NSStatusItem!
    let navigationEngine = NavigationEngine()
    var navigationCoordinator: NavigationCoordinator!

    var hotkeyManager: HotkeyManager!
    var overlayController: OverlayWindowController!
    private var cancellables = Set<AnyCancellable>()

    private var mainMenu: NSMenu!

    public func applicationDidFinishLaunching(_: Notification) {
        navigationCoordinator = NavigationCoordinator(engine: navigationEngine)
        // Create the status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Using a system symbol or a simple text
            button.image = NSImage(systemSymbolName: "cursorarrow.and.square.on.square.dashed", accessibilityDescription: "DivvyClick")
            button.title = "⌘"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Define menu
        mainMenu = NSMenu()
        mainMenu.addItem(NSMenuItem(title: "Start Navigation", action: #selector(startNav), keyEquivalent: "s"))
        mainMenu.addItem(NSMenuItem(title: "Stop Navigation", action: #selector(stopNav), keyEquivalent: "x"))
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(NSMenuItem(title: "Quit Divvy-click", action: #selector(quitApp), keyEquivalent: "q"))

        hotkeyManager = HotkeyManager(coordinator: navigationCoordinator)
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

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            statusItem.menu = mainMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            if navigationEngine.isActive {
                navigationEngine.stop()
            } else {
                navigationEngine.start()
            }
        }
    }

    @objc func startNav() {
        navigationEngine.start()
    }

    @objc func stopNav() {
        navigationEngine.stop()
    }

    public func applicationWillTerminate(_: Notification) {
        // Teardown
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
