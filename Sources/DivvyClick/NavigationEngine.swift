import AppKit
import Foundation

@MainActor
class NavigationEngine: ObservableObject {
    @Published var currentRegion: CGRect?
    @Published var activeScreenFrame: CGRect = .zero
    @Published var isActive: Bool = false
    @Published var isSelectingDisplay: Bool = false

    // Original screen to constrain navigation
    private var activeScreen: NSScreen?
    private let cursorEngine = CursorEngine()
    
    private var history: [CGRect] = []
    private var redoStack: [CGRect] = []

    func start() {
        // Find screen under current cursor
        let mouseLoc = NSEvent.mouseLocation
        activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main

        guard let screen = activeScreen else { return }
        activeScreenFrame = screen.frame
        currentRegion = screen.frame
        isActive = true
        history = []
        redoStack = []
    }

    func stop() {
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
    }

    @discardableResult
    func undo() -> Bool {
        guard isActive, let current = currentRegion, !history.isEmpty else { return false }
        redoStack.append(current)
        currentRegion = history.removeLast()
        return true
    }

    func redo() {
        guard isActive, let current = currentRegion, !redoStack.isEmpty else { return }
        history.append(current)
        currentRegion = redoStack.removeLast()
    }

    /// Divide the current region into parts with an overlapping "venn" zone.
    func vennfurcate(_ direction: Direction) {
        guard isActive, let region = currentRegion else { return }
        
        history.append(region)
        redoStack.removeAll()

        let overlap: CGFloat = 0.33 // 1/3 overlap
        let expansionFactor = (1.0 + overlap) / 2.0 

        var newRegion = region
        let originalWidth = region.size.width
        let originalHeight = region.size.height
        
        // Handle Horizontal component
        switch direction {
        case .left, .topLeft, .bottomLeft:
            newRegion.size.width *= expansionFactor
        case .right, .topRight, .bottomRight:
            newRegion.size.width *= expansionFactor
            newRegion.origin.x += (originalWidth - newRegion.size.width)
        default: break
        }
        
        // Handle Vertical component
        switch direction {
        case .up, .topLeft, .topRight:
            newRegion.size.height *= expansionFactor
            newRegion.origin.y += (originalHeight - newRegion.size.height)
        case .down, .bottomLeft, .bottomRight:
            newRegion.size.height *= expansionFactor
        default: break
        }

        currentRegion = newRegion
    }

    @Published var isMouseDown: Bool = false

    func execute(_ action: Action) {
        guard isActive, let region = currentRegion else { return }

        // 1. Relocate cursor
        cursorEngine.jump(to: region)

        // 2. Perform action with a slight delay if it involves a click
        switch action {
        case .click:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .left)
                self.resetToFullScreen()
            }
        case .rightClick:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .right)
                self.resetToFullScreen()
            }
        case .move:
            // If mouse is currently down, we should send a drag event to the new location
            if isMouseDown {
                cursorEngine.mouseDrag(button: .left)
            } else {
                self.resetToFullScreen()
            }
        case .mouseDown:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.mouseDown(button: .left)
                self.isMouseDown = true
                self.start()
            }
        case .mouseUp:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.mouseUp(button: .left)
                self.isMouseDown = false
                self.resetToFullScreen()
            }
        case .scroll(let direction):
            let delta: Int32 = 100
            switch direction {
            case .up:    self.cursorEngine.scroll(deltaY: delta)
            case .down:  self.cursorEngine.scroll(deltaY: -delta)
            case .left:  self.cursorEngine.scroll(deltaX: -delta)
            case .right: self.cursorEngine.scroll(deltaX: delta)
            }
        }
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
    }

    enum Action {
        case click, rightClick, move, mouseDown, mouseUp
        case scroll(ScrollDirection)
    }

    enum ScrollDirection {
        case up, down, left, right
    }
}
