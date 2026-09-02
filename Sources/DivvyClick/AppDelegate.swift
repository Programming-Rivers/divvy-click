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
        buildMainMenu()

        hotkeyManager = HotkeyManager(coordinator: navigationCoordinator)
        overlayController = OverlayWindowController(engine: navigationEngine)

        // Update layout menu when active layout changes
        navigationEngine.layoutRegistry.$activeLayout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLayoutMenu()
            }
            .store(in: &cancellables)

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

    private var layoutSubmenu: NSMenu!

    private func buildMainMenu() {
        mainMenu = NSMenu()
        mainMenu.addItem(NSMenuItem(title: "Start Navigation", action: #selector(startNav), keyEquivalent: ""))
        mainMenu.addItem(NSMenuItem(title: "Stop Navigation", action: #selector(stopNav), keyEquivalent: ""))
        mainMenu.addItem(NSMenuItem.separator())

        let layoutMenuItem = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
        layoutSubmenu = NSMenu()
        layoutMenuItem.submenu = layoutSubmenu
        mainMenu.addItem(layoutMenuItem)
        updateLayoutMenu()

        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(NSMenuItem(title: "Quit DivvyClick", action: #selector(quitApp), keyEquivalent: ""))
    }

    private func updateLayoutMenu() {
        guard layoutSubmenu != nil else { return }
        layoutSubmenu.removeAllItems()
        let activeId = navigationEngine.activeLayout.id
        for layout in navigationEngine.layoutRegistry.registeredLayouts {
            let item = NSMenuItem(title: layout.name, action: #selector(layoutSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.id
            item.state = (layout.id == activeId) ? .on : .off
            layoutSubmenu.addItem(item)
        }
    }

    @objc func layoutSelected(_ sender: NSMenuItem) {
        if let layoutId = sender.representedObject as? String {
            navigationEngine.layoutRegistry.selectLayout(byId: layoutId)
            updateLayoutMenu()
        }
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
