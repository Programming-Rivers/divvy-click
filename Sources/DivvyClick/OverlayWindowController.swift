import AppKit
import Combine
import SwiftUI

@MainActor
class OverlayWindowController {
    private var window: NSPanel
    let engine: NavigationEngine
    private var cancellables = Set<AnyCancellable>()

    init(engine: NavigationEngine) {
        self.engine = engine

        window = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true

        let hostingView = NSHostingView(rootView: GridOverlayView(engine: engine))
        window.contentView = hostingView

        // Observe engine region and active screen frame
        Publishers.CombineLatest(engine.$currentRegion, engine.$activeScreenFrame)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] region, screenFrame in
                guard let self = self else { return }
                if region != nil {
                    if self.window.frame != screenFrame {
                        self.window.setFrame(screenFrame, display: true)
                    }
                    self.window.orderFrontRegardless()
                } else {
                    self.window.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }
}
