import Foundation
import CoreGraphics

enum KeyCode: Int64, CaseIterable {
    case y = 16, u = 32, i = 34, o = 31
    case h = 4,  j = 38, k = 40, l = 37
    case n = 45, m = 46, comma = 43, period = 47
    case semicolon = 41, escape = 53
    case a = 0, s = 1, d = 2, f = 3
    case space = 49
    case slash = 44


    var string: String {
        switch self {
        case .y: return "Y"
        case .u: return "U"
        case .i: return "I"
        case .o: return "O"
        case .h: return "H"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .n: return "N"
        case .m: return "M"
        case .comma: return ","
        case .period: return "."
        case .semicolon: return ";"
        case .escape: return "Esc"
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .space: return "Space"
        case .slash: return "/"

        }
    }
    
    static func from(string: String) -> KeyCode? {
        return KeyCode.allCases.first { $0.string == string }
    }
}

struct KeyBinding: Sendable {
    let label: String
    let action: (@MainActor @Sendable (NavigationCoordinator, CGEventFlags) -> Void)?

    init(label: String, action: (@MainActor @Sendable (NavigationCoordinator, CGEventFlags) -> Void)? = nil) {
        self.label = label
        self.action = action
    }
}

struct KeyMap: Sendable {
    let mappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]]

    init(mappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] = KeyMap.defaultMappings) {
        self.mappings = mappings
    }

    init(layout: any NavigationLayout) {
        self.mappings = KeyMap.createMappings(for: layout)
    }

    static let `default` = KeyMap(layout: OverlappingPairsLayout())

    static var defaultMappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] {
        createMappings(for: OverlappingPairsLayout())
    }

    static let defaultActionMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
        .j: KeyBinding(label: "Double") { coordinator, flags in coordinator.execute(.doubleClick, flags: flags) },
        .k: KeyBinding(label: "Middle") { coordinator, flags in coordinator.execute(.middleClick, flags: flags) },
        .l: KeyBinding(label: "Left Click") { coordinator, flags in coordinator.execute(.click, flags: flags) },
        .m: KeyBinding(label: "Start Drag") { coordinator, flags in coordinator.execute(.mouseDown, flags: flags) },
        .comma: KeyBinding(label: "Drop") { coordinator, flags in coordinator.execute(.mouseUp, flags: flags) }
    ]

    static let defaultScrollMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
        .u: KeyBinding(label: "Scroll Up") { coordinator, flags in coordinator.execute(.scroll(.up), flags: flags) },
        .i: KeyBinding(label: "Auto Up") { coordinator, _ in coordinator.execute(.autoScroll(.up)) },
        .k: KeyBinding(label: "Stop") { coordinator, _ in coordinator.execute(.autoScroll(nil)) },
        .m: KeyBinding(label: "Scroll Down") { coordinator, flags in coordinator.execute(.scroll(.down), flags: flags) },
        .comma: KeyBinding(label: "Auto Down") { coordinator, _ in coordinator.execute(.autoScroll(.down)) },
        .j: KeyBinding(label: "Scroll Left") { coordinator, flags in coordinator.execute(.scroll(.left), flags: flags) },
        .l: KeyBinding(label: "Scroll Right") { coordinator, flags in coordinator.execute(.scroll(.right), flags: flags) }
    ]

    static let defaultManagementMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in if !coordinator.engine.undo() { coordinator.engine.showDisplaySelection() } },
        .j: KeyBinding(label: "Redo") { coordinator, _ in coordinator.engine.redo() },
        .k: KeyBinding(label: "Reset") { coordinator, _ in coordinator.engine.reset() },
        .l: KeyBinding(label: "Display") { coordinator, _ in coordinator.engine.showDisplaySelection() }
    ]

    static func createMappings(for layout: any NavigationLayout) -> [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] {
        var map: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] = [
            .action: defaultActionMappings,
            .scroll: defaultScrollMappings,
            .management: defaultManagementMappings
        ]

        // Fast Move Layer (S)
        var fastMoveMap: [KeyCode: KeyBinding] = [
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() }
        ]
        for (key, tileBinding) in layout.fastMoveBindings {
            let tileId = tileBinding.tileId
            let count = tileBinding.fastRepeatCount
            fastMoveMap[key] = KeyBinding(label: tileBinding.label) { coordinator, _ in
                for _ in 0..<count {
                    coordinator.engine.navigate(tileId: tileId)
                }
            }
        }
        map[.fastMove] = fastMoveMap

        // Default Navigation Layer
        var defaultNavMap: [KeyCode: KeyBinding] = [
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() }
        ]
        for (key, tileBinding) in layout.defaultNavBindings {
            let tileId = tileBinding.tileId
            defaultNavMap[key] = KeyBinding(label: tileBinding.label) { coordinator, _ in
                coordinator.engine.navigate(tileId: tileId)
            }
        }
        map[.defaultNav] = defaultNavMap

        return map
    }

    func label(for layer: NavigationEngine.ActiveLayer, key: KeyCode) -> String? {
        return mappings[layer]?[key]?.label
    }

    @MainActor
    func execute(for layer: NavigationEngine.ActiveLayer, key: KeyCode, coordinator: NavigationCoordinator, flags: CGEventFlags) -> Bool {
        if let binding = mappings[layer]?[key], let action = binding.action {
            action(coordinator, flags)
            return true
        }
        return false
    }
}

