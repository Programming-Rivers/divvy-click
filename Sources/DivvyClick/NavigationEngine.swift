import AppKit
import DivvyClickCore
import DivvyClickLayouts

@MainActor
public class NavigationEngine: ObservableObject {
    @Published public var currentTarget: NavigationTarget?
    public var currentRegion: CGRect? { currentTarget?.region }
    @Published public var activeScreenFrame: CGRect = .zero
    @Published public var isActive: Bool = false
    @Published public var isSelectingDisplay: Bool = false
    public let layerState = LayerState()
    public let scrollState = ScrollState()


    // Original screen bounding box to constrain navigation
    // (We formerly held NSScreen directly, but holding CGRect makes testing purely deterministic)
    private var history: [NavigationTarget] = []
    private var redoStack: [NavigationTarget] = []
    private let maxStackSize = AppConstants.maxHistorySize
    private let screenProvider: ScreenProviding
    public let layoutRegistry: LayoutRegistry

    public var activeLayout: any NavigationLayout {
        layoutRegistry.activeLayout
    }

    public init(screenProvider: ScreenProviding = SystemScreenProvider(), layoutRegistry: LayoutRegistry? = nil) {
        self.screenProvider = screenProvider
        self.layoutRegistry = layoutRegistry ?? .shared
    }

    public func start() {
        layerState.activeLayer = nil
        isActive = true
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
    }

    public func stop() {
        isActive = false
        isSelectingDisplay = false
        layerState.showHUD = false
        layerState.activeLayer = nil
        isMouseDown = false
    }


    /// Like stop, but also clear the target and history.
    public func reset() {
        stop()
        currentTarget = nil
        history = []
        redoStack = []
    }


    public func showDisplaySelection() {
        let mouseLoc = screenProvider.mouseLocation
        let frame = screenProvider.screenFrame(at: mouseLoc) ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        activeScreenFrame = frame
        currentTarget = .region(frame)
        isActive = true
        history = []
        isSelectingDisplay = true
    }

    public func selectDisplay(at index: Int) {
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
    public func screenMapping() -> [Int: CGRect] {
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

        // 4. Compress grid to remove empty rows and columns
        var assigned = mapping.map { ($0.key % 3, $0.key / 3, $0.value) }

        let activeRows = Set(assigned.map { $0.1 }).sorted()
        var rowMap: [Int: Int] = [:]
        for (i, r) in activeRows.enumerated() { rowMap[r] = i }

        let activeCols = Set(assigned.map { $0.0 }).sorted()
        var colMap: [Int: Int] = [:]
        for (i, c) in activeCols.enumerated() { colMap[c] = i }

        // Apply compression mapping
        assigned = assigned.map { (colMap[$0.0]!, rowMap[$0.1]!, $0.2) }

        // 5. Center the compressed grid
        let maxGx = assigned.map { $0.0 }.max() ?? 0
        let maxGy = assigned.map { $0.1 }.max() ?? 0

        let shiftX = (3 - (maxGx + 1)) / 2
        let shiftY = (3 - (maxGy + 1)) / 2

        var finalMapping: [Int: CGRect] = [:]
        for (gx, gy, screen) in assigned {
            let finalX = gx + shiftX
            let finalY = gy + shiftY
            finalMapping[finalY * 3 + finalX] = screen
        }

        return finalMapping
    }

    @discardableResult
    public func undo() -> Bool {
        guard let current = currentTarget, !history.isEmpty else { return false }
        redoStack.append(current)
        if redoStack.count > maxStackSize {
            redoStack.removeFirst()
        }
        
        let target = history.removeLast()
        currentTarget = target
        
        if case .restoreCursor = target {
            isActive = false
        } else {
            isActive = true // Reactivate if it was hidden
        }
        return true
    }

    public func redo() {
        guard let current = currentTarget, !redoStack.isEmpty else { return }
        history.append(current)
        pruneHistory()
        currentTarget = redoStack.removeLast()
        isActive = true // Reactivate if it was hidden
    }

    private func pruneHistory() {
        if history.count > maxStackSize {
            if case .restoreCursor = history.first {
                if history.count > 1 {
                    history.remove(at: 1)
                }
            } else {
                history.removeFirst()
            }
        }
    }

    /// Subdivide the current region using the active layout and the specified tile identifier.
    public func navigate(tileId: String) {
        guard isActive, let current = currentTarget, let region = current.region else { return }

        history.append(current)
        pruneHistory()
        redoStack.removeAll()

        let nextRegion = layoutRegistry.activeLayout.subdivide(region: region, tileId: tileId, screenFrame: activeScreenFrame)
        currentTarget = .region(nextRegion)
    }

    /// Convenience method to subdivide based on a Direction enum.
    public func vennfurcate(_ direction: Direction) {
        navigate(tileId: direction.tileId)
    }

    @Published public var isMouseDown: Bool = false

    public enum Direction: Sendable {
        case up, down, left, right
        case topLeft, topRight, bottomLeft, bottomRight
        case center

        public var tileId: String {
            switch self {
            case .up: return "up"
            case .down: return "down"
            case .left: return "left"
            case .right: return "right"
            case .topLeft: return "topLeft"
            case .topRight: return "topRight"
            case .bottomLeft: return "bottomLeft"
            case .bottomRight: return "bottomRight"
            case .center: return "center"
            }
        }
    }



    public enum Action: Sendable {
        case click, doubleClick, rightClick, middleClick, move, mouseDown, mouseUp
        case scroll(ScrollDirection)
        case autoScroll(ScrollDirection?)
    }

    public enum ScrollDirection: Sendable {
        case up, down, left, right
    }

    public enum ActiveLayer: Sendable {
        case action, scroll, fastMove, management, defaultNav
    }
}
