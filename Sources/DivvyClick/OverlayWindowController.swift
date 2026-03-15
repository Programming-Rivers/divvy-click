import AppKit
import Combine
import SwiftUI

@MainActor
class OverlayWindowController {
    let window: NSWindow
    let engine: NavigationEngine
    private var cancellables = Set<AnyCancellable>()

    init(engine: NavigationEngine) {
        self.engine = engine

        // Create the borderless, floating window
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating // Stay above normal windows
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show on all desktops
        window.ignoresMouseEvents = true // Let clicks pass through if somehow it isn't closed
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false

        // Attach the SwiftUI View
        let hostingView = NSHostingView(rootView: GridOverlayView(engine: engine))
        window.contentView = hostingView

        // Observe engine region
        engine.$currentRegion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] region in
                guard let self = self else { return }
                if let r = region {
                    self.window.setFrame(r, display: true, animate: true)
                    self.window.orderFront(nil)
                } else {
                    self.window.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }
}
