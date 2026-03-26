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
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
            .j: KeyBinding(label: "Double") { coordinator, flags in coordinator.execute(.doubleClick, flags: flags) },
            .k: KeyBinding(label: "Left Click") { coordinator, flags in coordinator.execute(.click, flags: flags) },
            .l: KeyBinding(label: "Right Click") { coordinator, flags in coordinator.execute(.rightClick, flags: flags) },
            .m: KeyBinding(label: "Start Drag") { coordinator, flags in coordinator.execute(.mouseDown, flags: flags) },
            .comma: KeyBinding(label: "Drop") { coordinator, flags in coordinator.execute(.mouseUp, flags: flags) },
            .period: KeyBinding(label: "Middle") { coordinator, flags in coordinator.execute(.middleClick, flags: flags) }
        ]
        
        // Scroll Layer (D)
        mappings[.scroll] = [
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
            .i: KeyBinding(label: "Scroll Up") { coordinator, flags in coordinator.execute(.scroll(.up), flags: flags) },
            .comma: KeyBinding(label: "Scroll Down") { coordinator, flags in coordinator.execute(.scroll(.down), flags: flags) },
            .j: KeyBinding(label: "Scroll Left") { coordinator, flags in coordinator.execute(.scroll(.left), flags: flags) },
            .l: KeyBinding(label: "Scroll Right") { coordinator, flags in coordinator.execute(.scroll(.right), flags: flags) }
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
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
            .u: KeyBinding(label: "Fast ↖") { coordinator, _ in coordinator.engine.vennfurcate(.topLeft); coordinator.engine.vennfurcate(.topLeft) },
            .i: KeyBinding(label: "Fast ↑") { coordinator, _ in coordinator.engine.vennfurcate(.up); coordinator.engine.vennfurcate(.up) },
            .o: KeyBinding(label: "Fast ↗") { coordinator, _ in coordinator.engine.vennfurcate(.topRight); coordinator.engine.vennfurcate(.topRight) },
            .j: KeyBinding(label: "Fast ←") { coordinator, _ in coordinator.engine.vennfurcate(.left); coordinator.engine.vennfurcate(.left) },
            .k: KeyBinding(label: "Fast ○") { coordinator, _ in coordinator.engine.vennfurcate(.center); coordinator.engine.vennfurcate(.center) },
            .l: KeyBinding(label: "Fast →") { coordinator, _ in coordinator.engine.vennfurcate(.right); coordinator.engine.vennfurcate(.right) },
            .m: KeyBinding(label: "Fast ↙") { coordinator, _ in coordinator.engine.vennfurcate(.bottomLeft); coordinator.engine.vennfurcate(.bottomLeft) },
            .comma: KeyBinding(label: "Fast ↓") { coordinator, _ in coordinator.engine.vennfurcate(.down); coordinator.engine.vennfurcate(.down) },
            .period: KeyBinding(label: "Fast ↘") { coordinator, _ in coordinator.engine.vennfurcate(.bottomRight); coordinator.engine.vennfurcate(.bottomRight) }
        ]
        
        // Default Navigation
        mappings[.defaultNav] = [
            .h: KeyBinding(label: "Undo") { coordinator, _ in coordinator.engine.undo() },
            .u: KeyBinding(label: "↖") { coordinator, _ in coordinator.engine.vennfurcate(.topLeft) },
            .i: KeyBinding(label: "↑") { coordinator, _ in coordinator.engine.vennfurcate(.up) },
            .o: KeyBinding(label: "↗") { coordinator, _ in coordinator.engine.vennfurcate(.topRight) },
            .j: KeyBinding(label: "←") { coordinator, _ in coordinator.engine.vennfurcate(.left) },
            .k: KeyBinding(label: "○") { coordinator, _ in coordinator.engine.vennfurcate(.center) },
            .l: KeyBinding(label: "→") { coordinator, _ in coordinator.engine.vennfurcate(.right) },
            .m: KeyBinding(label: "↙") { coordinator, _ in coordinator.engine.vennfurcate(.bottomLeft) },
            .comma: KeyBinding(label: "↓") { coordinator, _ in coordinator.engine.vennfurcate(.down) },
            .period: KeyBinding(label: "↘") { coordinator, _ in coordinator.engine.vennfurcate(.bottomRight) }
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

