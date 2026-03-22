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
    private let cursorEngine = CursorEngine()
    
    private var history: [CGRect] = []
    private var redoStack: [CGRect] = []

    func start() {
        if currentRegion == nil {
            // Only search for screen if we don't already have one in history
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
        // DO NOT reset currentRegion, screen, or history here.
        // This allows user to resume from last location.
    }

    /// Completely reset the engine state to full screen
    func reset() {
        isActive = false
        isSelectingDisplay = false
        currentRegion = nil
        activeScreen = nil
        history = []
        redoStack = []
    }

    func showDisplaySelection() {
        // Find screen under current cursor to show the selection UI
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
        
        autoMoveIfDragging()
    }

    @discardableResult
    func undo() -> Bool {
        guard let current = currentRegion, !history.isEmpty else { return false }
        redoStack.append(current)
        currentRegion = history.removeLast()
        isActive = true // Reactivate if it was hidden
        autoMoveIfDragging()
        return true
    }

    func redo() {
        guard let current = currentRegion, !redoStack.isEmpty else { return }
        history.append(current)
        currentRegion = redoStack.removeLast()
        isActive = true // Reactivate if it was hidden
        autoMoveIfDragging()
    }

    /// Divide the current region into parts with an overlapping "venn" zone.
    func vennfurcate(_ direction: Direction) {
        guard isActive, let region = currentRegion else { return }
        
        history.append(region)
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
        autoMoveIfDragging()
    }

    @Published var isMouseDown: Bool = false

    func execute(_ action: Action, flags: CGEventFlags = []) {
        guard let region = currentRegion else { return }

        let targetPoint = CGPoint(x: region.midX, y: region.midY)

        // 2. Perform action with a slight delay if it involves a click
        switch action {
        case .click:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .left, flags: flags, at: targetPoint)
                self.stop()
            }
        case .doubleClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .left, count: 2, flags: flags, at: targetPoint)
                self.stop()
            }
        case .rightClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .right, flags: flags, at: targetPoint)
                self.stop()
            }
        case .middleClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .center, flags: flags, at: targetPoint)
                self.stop()
            }
        case .move:
            // If mouse is currently down, we should send a drag event to the new location
            if isMouseDown {
                // For drags, we avoid the 'jump' (warp) as it can break some apps' drag logic.
                // The drag event itself carries the location.
                cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
            } else {
                cursorEngine.jump(to: region)
                self.stop()
            }
        case .mouseDown:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.mouseDown(button: .left, flags: flags, at: targetPoint)
                self.isMouseDown = true
                // Prime the drag: some apps need an initial drag event at the start location 
                // to realize a drag session has truly begun.
                self.cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
                self.start()
            }
        case .mouseUp:
            // Same as move: avoid warp if we are currently dragging
            if isMouseDown {
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            } else {
                cursorEngine.jump(to: region)
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isMouseDown = false
                self.reset()
                self.start()
            }
        case .scroll(let direction):
            let delta: Int32 = 100
            switch direction {
            case .up:    self.cursorEngine.scroll(deltaY: delta, flags: flags)
            case .down:  self.cursorEngine.scroll(deltaY: -delta, flags: flags)
            case .left:  self.cursorEngine.scroll(deltaX: -delta, flags: flags)
            case .right: self.cursorEngine.scroll(deltaX: delta, flags: flags)
            }
        }
    }

    private func autoMoveIfDragging() {
        guard isMouseDown, let region = currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)
        // During continuous navigation (venn/undo/redo), we use mouseDrag 
        // to keep the OS/Apps updated on the 'active' drag location.
        cursorEngine.mouseDrag(button: .left, at: targetPoint)
    }

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
