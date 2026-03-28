import AppKit

@MainActor
class NavigationEngine: ObservableObject {
    @Published var currentTarget: NavigationTarget?
    var currentRegion: CGRect? { currentTarget?.region }
    @Published var activeScreenFrame: CGRect = .zero
    @Published var isActive: Bool = false {
        didSet {
            HotkeyManager.isActiveCached = isActive
        }
    }
    @Published var isSelectingDisplay: Bool = false
    let layerState = LayerState()
    let scrollState = ScrollState()


    // Original screen bounding box to constrain navigation
    // (We formerly held NSScreen directly, but holding CGRect makes testing purely deterministic)
    private var history: [NavigationTarget] = []
    private var redoStack: [NavigationTarget] = []
    private let maxStackSize = AppConstants.maxHistorySize
    private let screenProvider: ScreenProviding

    init(screenProvider: ScreenProviding = SystemScreenProvider()) {
        self.screenProvider = screenProvider
    }

    func start() {
        if currentTarget == nil {
            let mouseLoc = screenProvider.mouseLocation
            let frame = screenProvider.screenFrame(at: mouseLoc) ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            
            // Storing the mouse location as a marker for the "Final Undo"
            // Using a restoreCursor target as a marker
            let marker = NavigationTarget.restoreCursor(mouseLoc)
            activeScreenFrame = frame
            currentTarget = .region(frame)
            history = [marker]
            redoStack = []
        }
        isActive = true
    }

    func stop() {
        isActive = false
        isSelectingDisplay = false
        layerState.showHUD = false
    }


    func reset() {
        isActive = false
        isSelectingDisplay = false
        layerState.showHUD = false
        currentTarget = nil
        history = []
        redoStack = []
    }


    func showDisplaySelection() {
        let mouseLoc = screenProvider.mouseLocation
        let frame = screenProvider.screenFrame(at: mouseLoc) ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        activeScreenFrame = frame
        currentTarget = .region(frame)
        isActive = true
        history = []
        isSelectingDisplay = true
    }

    func selectDisplay(at index: Int) {
        let screens = screenMapping()
        guard index >= 0 && index < 9, let frame = screens[index] else { return }
        
        activeScreenFrame = frame
        currentTarget = .region(frame)
        isSelectingDisplay = false
        isActive = true
        history = []
        redoStack = []
    }

    /// Maps physical screens to a 3x3 grid (indices 0-8) based on their physical arrangement.
    func screenMapping() -> [Int: CGRect] {
        let screens = screenProvider.screens
        guard !screens.isEmpty else { return [:] }

        // 1. Calculate the overall bounding box
        let minX = screens.map { $0.minX }.min() ?? 0
        let maxX = screens.map { $0.maxX }.max() ?? 0
        let minY = screens.map { $0.minY }.min() ?? 0
        let maxY = screens.map { $0.maxY }.max() ?? 0

        let totalWidth = max(1, maxX - minX)
        let totalHeight = max(1, maxY - minY)

        var mapping: [Int: CGRect] = [:]

        // 2. Map screens to grid cells based on normalized coordinates
        for screen in screens {
            let cx = screen.midX
            let cy = screen.midY

            let nx = (cx - minX) / totalWidth
            let ny = (cy - minY) / totalHeight

            // macOS origin is bottom-left, so high NY = Top (gy=0)
            let gx = min(max(Int(floor(nx * 3)), 0), 2)
            let gy = min(max(2 - Int(floor(ny * 3)), 0), 2)
            
            var index = gy * 3 + gx
            
            // 3. Collision handling: if cell is occupied, find the nearest free cell
            if mapping[index] != nil {
                let neighbors = [
                    (gx-1, gy), (gx+1, gy), (gx, gy-1), (gx, gy+1),
                    (gx-1, gy-1), (gx+1, gy-1), (gx-1, gy+1), (gx+1, gy+1)
                ]
                for (nx, ny) in neighbors where nx >= 0 && nx < 3 && ny >= 0 && ny < 3 {
                    let nextIndex = ny * 3 + nx
                    if mapping[nextIndex] == nil {
                        index = nextIndex
                        break
                    }
                }
            }
            
            mapping[index] = screen
        }

        return mapping
    }

    @discardableResult
    func undo() -> Bool {
        guard let current = currentTarget, !history.isEmpty else { return false }
        redoStack.append(current)
        if redoStack.count > maxStackSize {
            redoStack.removeFirst()
        }
        currentTarget = history.removeLast()
        isActive = true // Reactivate if it was hidden
        return true
    }

    func redo() {
        guard let current = currentTarget, !redoStack.isEmpty else { return }
        history.append(current)
        if history.count > maxStackSize {
            history.removeFirst()
        }
        currentTarget = redoStack.removeLast()
        isActive = true // Reactivate if it was hidden
    }

    /// Divide the current region into parts with an overlapping "venn" zone.
    func vennfurcate(_ direction: Direction) {
        guard isActive, let current = currentTarget, let region = current.region else { return }
        
        history.append(current)
        if history.count > maxStackSize {
            history.removeFirst()
        }
        redoStack.removeAll()

        // 3x3 grid with slight overlap
        let overlapFactor: CGFloat = CGFloat(AppConstants.overlapFactor) 
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
        let clampedRegion = newRegion.intersection(activeScreenFrame)
        currentTarget = .region(clampedRegion)
    }

    @Published var isMouseDown: Bool = false

    enum Direction {
        case left, right, up, down
        case topLeft, topRight, bottomLeft, bottomRight
        case center
    }



    enum Action {
        case click, doubleClick, rightClick, middleClick, move, mouseDown, mouseUp
        case scroll(ScrollDirection)
        case autoScroll(ScrollDirection?)
    }

    enum ScrollDirection {
        case up, down, left, right
    }

    enum ActiveLayer {
        case action, scroll, fastMove, management, defaultNav
    }
}
