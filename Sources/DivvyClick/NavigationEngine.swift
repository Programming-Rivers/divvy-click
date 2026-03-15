import AppKit
import Foundation

@MainActor
class NavigationEngine: ObservableObject {
    @Published var currentRegion: CGRect?
    @Published var isActive: Bool = false

    // Original screen to constrain navigation
    private var activeScreen: NSScreen?
    private let cursorEngine = CursorEngine()

    func start() {
        // Find screen under current cursor
        let mouseLoc = NSEvent.mouseLocation
        activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main

        guard let screen = activeScreen else { return }
        currentRegion = screen.frame
        isActive = true
    }

    func stop() {
        isActive = false
        currentRegion = nil
        activeScreen = nil
    }

    func bifurcate(_ direction: Direction) {
        guard isActive, let region = currentRegion else { return }

        var newRegion = region
        switch direction {
        case .left:
            newRegion.size.width /= 2
        case .right:
            newRegion.size.width /= 2
            newRegion.origin.x += newRegion.size.width
        case .up: // AppKit coordinate system: origin is bottom-left
            newRegion.size.height /= 2
            newRegion.origin.y += newRegion.size.height
        case .down:
            newRegion.size.height /= 2
        }

        currentRegion = newRegion
    }

    func executeClick() {
        guard isActive, let region = currentRegion else { return }

        // 1. Relocate cursor
        cursorEngine.jump(to: region)

        // 2. Stop navigation (hides overlay)
        stop()

        // 3. Very slight delay to let macOS register the new cursor position before clicking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.cursorEngine.click()
        }
    }

    enum Direction {
        case left, right, up, down
    }
}
