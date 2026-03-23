import AppKit
import Foundation

@MainActor
class NavigationEngine: ObservableObject {
    @Published var currentRegion: CGRect?
    @Published var activeScreenFrame: CGRect = .zero
    @Published var isActive: Bool = false
    @Published var isSelectingDisplay: Bool = false
    @Published var activeLayer: ActiveLayer? = nil

    // Original screen to constrain navigation
    private var activeScreen: NSScreen?
    private var history: [CGRect] = []
    private var redoStack: [CGRect] = []
    private let maxStackSize = 100

    func start() {
        if currentRegion == nil {
            let mouseLoc = NSEvent.mouseLocation
            activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
            
            guard let screen = activeScreen else { return }
            activeScreenFrame = screen.frame
            currentRegion = screen.frame
            history = []
            redoStack = []
        }
        isActive = true
    }

    func stop() {
        isActive = false
        isSelectingDisplay = false
    }

    func reset() {
        isActive = false
        isSelectingDisplay = false
        currentRegion = nil
        activeScreen = nil
        history = []
        redoStack = []
    }

    func showDisplaySelection() {
        let mouseLoc = NSEvent.mouseLocation
        activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
        
        guard let screen = activeScreen else { return }
        activeScreenFrame = screen.frame
        currentRegion = screen.frame
        isActive = true
        isSelectingDisplay = true
    }

    func selectDisplay(at index: Int) {
        let screens = NSScreen.screens
        guard index >= 0 && index < screens.count else { return }
        
        let selectedScreen = screens[index]
        activeScreen = selectedScreen
        activeScreenFrame = selectedScreen.frame
        currentRegion = selectedScreen.frame
        isSelectingDisplay = false
        isActive = true
        history = []
        redoStack = []
    }

    @discardableResult
    func undo() -> Bool {
        guard let current = currentRegion, !history.isEmpty else { return false }
        redoStack.append(current)
        if redoStack.count > maxStackSize {
            redoStack.removeFirst()
        }
        currentRegion = history.removeLast()
        isActive = true // Reactivate if it was hidden
        return true
    }

    func redo() {
        guard let current = currentRegion, !redoStack.isEmpty else { return }
        history.append(current)
        if history.count > maxStackSize {
            history.removeFirst()
        }
        currentRegion = redoStack.removeLast()
        isActive = true // Reactivate if it was hidden
    }

    /// Divide the current region into parts with an overlapping "venn" zone.
    func vennfurcate(_ direction: Direction) {
        guard isActive, let region = currentRegion else { return }
        
        history.append(region)
        if history.count > maxStackSize {
            history.removeFirst()
        }
        redoStack.removeAll()

        // 3x3 grid with slight overlap
        let overlapFactor: CGFloat = 1.1 
        let thirdWidth = (region.size.width / 3.0) * overlapFactor
        let thirdHeight = (region.size.height / 3.0) * overlapFactor

        let xStep = (region.size.width - thirdWidth) / 2.0
        let yStep = (region.size.height - thirdHeight) / 2.0

        var newRegion = region
        newRegion.size.width = thirdWidth
        newRegion.size.height = thirdHeight
        
        // Handle Horizontal component
        switch direction {
        case .left, .topLeft, .bottomLeft:
            newRegion.origin.x = region.origin.x
        case .right, .topRight, .bottomRight:
            newRegion.origin.x = region.origin.x + region.size.width - thirdWidth
        case .center, .up, .down:
            newRegion.origin.x = region.origin.x + xStep
        }
        
        // Handle Vertical component (macOS origin is bottom-left)
        switch direction {
        case .up, .topLeft, .topRight:
            newRegion.origin.y = region.origin.y + region.size.height - thirdHeight
        case .down, .bottomLeft, .bottomRight:
            newRegion.origin.y = region.origin.y
        case .center, .left, .right:
            newRegion.origin.y = region.origin.y + yStep
        }

        currentRegion = newRegion
    }

    @Published var isMouseDown: Bool = false

    private func resetToFullScreen() {
        guard let screen = activeScreen else { return }
        currentRegion = screen.frame
        history = []
        redoStack = []
    }

    enum Direction {
        case left, right, up, down
        case topLeft, topRight, bottomLeft, bottomRight
        case center
    }

    enum Action {
        case click, doubleClick, rightClick, middleClick, move, mouseDown, mouseUp
        case scroll(ScrollDirection)
    }

    enum ScrollDirection {
        case up, down, left, right
    }

    enum ActiveLayer {
        case action, scroll, fastMove, management, defaultNav
    }
}
