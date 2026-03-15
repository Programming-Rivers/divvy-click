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

    /// Divide the current region into two parts with an overlapping "venn" zone.
    func vennfurcate(_ direction: Direction) {
        guard isActive, let region = currentRegion else { return }

        let overlap: CGFloat = 0.33 // 1/3 overlap
        let expansionFactor = (1.0 + overlap) / 2.0 // e.g., 0.6 for 20% overlap

        var newRegion = region
        switch direction {
        case .left:
            newRegion.size.width *= expansionFactor
        case .right:
            let originalWidth = newRegion.size.width
            newRegion.size.width *= expansionFactor
            newRegion.origin.x += (originalWidth - newRegion.size.width)
        case .up: // AppKit coordinate system: origin is bottom-left
            let originalHeight = newRegion.size.height
            newRegion.size.height *= expansionFactor
            newRegion.origin.y += (originalHeight - newRegion.size.height)
        case .down:
            newRegion.size.height *= expansionFactor
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
