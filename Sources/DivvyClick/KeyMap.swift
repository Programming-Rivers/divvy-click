import CoreGraphics
import DivvyClickCore
import DivvyClickEngine
import DivvyClickLayouts
import Foundation

public struct KeyBinding: Sendable {
    public let label: String
    public let action: (@MainActor @Sendable (NavigationCoordinator, CGEventFlags) -> Void)?

    public init(label: String, action: (@MainActor @Sendable (NavigationCoordinator, CGEventFlags) -> Void)? = nil) {
        self.label = label
        self.action = action
    }
}

public struct KeyMap: Sendable {
    public let mappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]]

    public init(mappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] = KeyMap.defaultMappings) {
        self.mappings = mappings
    }

    public init(layout: any NavigationLayout) {
        self.mappings = KeyMap.createMappings(for: layout)
    }

    public static let `default` = KeyMap(layout: OverlappingPairsLayout())

    public static var defaultMappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] {
        createMappings(for: OverlappingPairsLayout())
    }

    public static let defaultActionMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
        .j: KeyBinding(label: "Double") { coordinator, flags in coordinator.execute(.doubleClick, flags: flags) },
        .k: KeyBinding(label: "Middle") { coordinator, flags in coordinator.execute(.middleClick, flags: flags) },
        .l: KeyBinding(label: "Left Click") { coordinator, flags in coordinator.execute(.click, flags: flags) },
        .m: KeyBinding(label: "Start Drag") { coordinator, flags in coordinator.execute(.mouseDown, flags: flags) },
        .comma: KeyBinding(label: "Drop") { coordinator, flags in coordinator.execute(.mouseUp, flags: flags) }
    ]

    public static let defaultScrollMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
        .u: KeyBinding(label: "Scroll Up") { coordinator, flags in coordinator.execute(.scroll(.up), flags: flags) },
        .i: KeyBinding(label: "Auto Up") { coordinator, _ in coordinator.execute(.autoScroll(.up)) },
        .k: KeyBinding(label: "Stop") { coordinator, _ in coordinator.execute(.autoScroll(nil)) },
        .m: KeyBinding(label: "Scroll Down") { coordinator, flags in coordinator.execute(.scroll(.down), flags: flags) },
        .comma: KeyBinding(label: "Auto Down") { coordinator, _ in coordinator.execute(.autoScroll(.down)) },
        .j: KeyBinding(label: "Scroll Left") { coordinator, flags in coordinator.execute(.scroll(.left), flags: flags) },
        .l: KeyBinding(label: "Scroll Right") { coordinator, flags in coordinator.execute(.scroll(.right), flags: flags) }
    ]

    public static let defaultManagementMappings: [KeyCode: KeyBinding] = [
        .h: KeyBinding(label: "Undo") { coordinator, _ in if !coordinator.engine.undo() { coordinator.engine.showDisplaySelection() } },
        .j: KeyBinding(label: "Redo") { coordinator, _ in coordinator.engine.redo() },
        .k: KeyBinding(label: "Reset") { coordinator, _ in coordinator.engine.reset() },
        .l: KeyBinding(label: "Display") { coordinator, _ in coordinator.engine.showDisplaySelection() }
    ]

    public static func createMappings(for layout: any NavigationLayout) -> [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] {
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

    public func label(for layer: NavigationEngine.ActiveLayer, key: KeyCode) -> String? {
        return mappings[layer]?[key]?.label
    }

    @MainActor
    public func execute(for layer: NavigationEngine.ActiveLayer, key: KeyCode, coordinator: NavigationCoordinator, flags: CGEventFlags) -> Bool {
        if let binding = mappings[layer]?[key], let action = binding.action {
            action(coordinator, flags)
            return true
        }
        return false
    }
}
