import Foundation
import CoreGraphics

enum KeyCode: Int64, CaseIterable {
    case y = 16, u = 32, i = 34
    case h = 4,  j = 38, k = 40, l = 37
    case n = 45, m = 46, comma = 43
    case semicolon = 41, escape = 53
    case a = 0, s = 1, d = 2, f = 3
    case space = 49

    var string: String {
        switch self {
        case .y: return "Y"
        case .u: return "U"
        case .i: return "I"
        case .h: return "H"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .n: return "N"
        case .m: return "M"
        case .comma: return ","
        case .semicolon: return ";"
        case .escape: return "Esc"
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .space: return "Space"
        }
    }
    
    static func from(string: String) -> KeyCode? {
        return KeyCode.allCases.first { $0.string == string }
    }
}

struct KeyBinding {
    let label: String
    let action: (@MainActor (NavigationCoordinator, CGEventFlags) -> Void)?
}

@MainActor
class KeyMap {
    static let shared = KeyMap()
    
    private var mappings: [NavigationEngine.ActiveLayer: [KeyCode: KeyBinding]] = [:]
    
    init() {
        setupMappings()
    }
    
    private func setupMappings() {
        // Action Layer (F)
        mappings[.action] = [
            .h: KeyBinding(label: "Double") { coordinator, flags in coordinator.execute(.doubleClick, flags: flags) },
            .j: KeyBinding(label: "Left Click") { coordinator, flags in coordinator.execute(.click, flags: flags) },
            .k: KeyBinding(label: "Middle") { coordinator, flags in coordinator.execute(.middleClick, flags: flags) },
            .l: KeyBinding(label: "Right Click") { coordinator, flags in coordinator.execute(.rightClick, flags: flags) },
            .n: KeyBinding(label: "Start Drag") { coordinator, flags in coordinator.execute(.mouseDown, flags: flags) },
            .m: KeyBinding(label: "Drop") { coordinator, flags in coordinator.execute(.mouseUp, flags: flags) }
        ]
        
        // Scroll Layer (D)
        mappings[.scroll] = [
            .u: KeyBinding(label: "Scroll Up") { coordinator, flags in coordinator.execute(.scroll(.up), flags: flags) },
            .m: KeyBinding(label: "Scroll Down") { coordinator, flags in coordinator.execute(.scroll(.down), flags: flags) },
            .h: KeyBinding(label: "Scroll Left") { coordinator, flags in coordinator.execute(.scroll(.left), flags: flags) },
            .k: KeyBinding(label: "Scroll Right") { coordinator, flags in coordinator.execute(.scroll(.right), flags: flags) }
        ]
        
        // Management Layer (A)
        mappings[.management] = [
            .h: KeyBinding(label: "Undo") { coordinator, _ in if !coordinator.engine.undo() { coordinator.engine.showDisplaySelection() } },
            .j: KeyBinding(label: "Redo") { coordinator, _ in coordinator.engine.redo() },
            .k: KeyBinding(label: "Reset") { coordinator, _ in coordinator.engine.reset() },
            .l: KeyBinding(label: "Display") { coordinator, _ in coordinator.engine.showDisplaySelection() }
        ]
        
        // Fast Move Layer (S)
        mappings[.fastMove] = [
            .y: KeyBinding(label: "Fast ↖") { coordinator, _ in coordinator.engine.vennfurcate(.topLeft); coordinator.engine.vennfurcate(.topLeft) },
            .u: KeyBinding(label: "Fast ↑") { coordinator, _ in coordinator.engine.vennfurcate(.up); coordinator.engine.vennfurcate(.up) },
            .i: KeyBinding(label: "Fast ↗") { coordinator, _ in coordinator.engine.vennfurcate(.topRight); coordinator.engine.vennfurcate(.topRight) },
            .h: KeyBinding(label: "Fast ←") { coordinator, _ in coordinator.engine.vennfurcate(.left); coordinator.engine.vennfurcate(.left) },
            .j: KeyBinding(label: "Fast ○") { coordinator, _ in coordinator.engine.vennfurcate(.center); coordinator.engine.vennfurcate(.center) },
            .k: KeyBinding(label: "Fast →") { coordinator, _ in coordinator.engine.vennfurcate(.right); coordinator.engine.vennfurcate(.right) },
            .n: KeyBinding(label: "Fast ↙") { coordinator, _ in coordinator.engine.vennfurcate(.bottomLeft); coordinator.engine.vennfurcate(.bottomLeft) },
            .m: KeyBinding(label: "Fast ↓") { coordinator, _ in coordinator.engine.vennfurcate(.down); coordinator.engine.vennfurcate(.down) },
            .comma: KeyBinding(label: "Fast ↘") { coordinator, _ in coordinator.engine.vennfurcate(.bottomRight); coordinator.engine.vennfurcate(.bottomRight) },
            .l: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() }
        ]
        
        // Default Navigation
        mappings[.defaultNav] = [
            .y: KeyBinding(label: "↖") { coordinator, _ in coordinator.engine.vennfurcate(.topLeft) },
            .u: KeyBinding(label: "↑") { coordinator, _ in coordinator.engine.vennfurcate(.up) },
            .i: KeyBinding(label: "↗") { coordinator, _ in coordinator.engine.vennfurcate(.topRight) },
            .h: KeyBinding(label: "←") { coordinator, _ in coordinator.engine.vennfurcate(.left) },
            .j: KeyBinding(label: "○") { coordinator, _ in coordinator.engine.vennfurcate(.center) },
            .k: KeyBinding(label: "→") { coordinator, _ in coordinator.engine.vennfurcate(.right) },
            .n: KeyBinding(label: "↙") { coordinator, _ in coordinator.engine.vennfurcate(.bottomLeft) },
            .m: KeyBinding(label: "↓") { coordinator, _ in coordinator.engine.vennfurcate(.down) },
            .comma: KeyBinding(label: "↘") { coordinator, _ in coordinator.engine.vennfurcate(.bottomRight) },
            .l: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() }
        ]
    }
    
    func label(for layer: NavigationEngine.ActiveLayer, key: KeyCode) -> String? {
        return mappings[layer]?[key]?.label
    }
    
    func execute(for layer: NavigationEngine.ActiveLayer, key: KeyCode, coordinator: NavigationCoordinator, flags: CGEventFlags) -> Bool {
        if let binding = mappings[layer]?[key], let action = binding.action {
            action(coordinator, flags)
            return true
        }
        return false
    }
}

