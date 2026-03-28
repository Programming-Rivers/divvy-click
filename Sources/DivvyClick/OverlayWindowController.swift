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

        let hostingView = NSHostingView(rootView: GridOverlayView(engine: engine, layerState: engine.layerState, scrollState: engine.scrollState))
        window.contentView = hostingView

        // Observe engine region, active screen frame, and active state
        Publishers.CombineLatest3(engine.$currentTarget, engine.$activeScreenFrame, engine.$isActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] region, screenFrame, isActive in
                guard let self = self else { return }
                
                if isActive, region != nil {
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
