import CoreGraphics
import Foundation

public enum KeyCode: Int64, CaseIterable, Sendable {
    case y = 16, u = 32, i = 34, o = 31
    case h = 4, j = 38, k = 40, l = 37
    case n = 45, m = 46, comma = 43, period = 47
    case semicolon = 41, escape = 53
    case a = 0, s = 1, d = 2, f = 3
    case space = 49
    case slash = 44

    public var string: String {
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

    public static func from(string: String) -> KeyCode? {
        return KeyCode.allCases.first { $0.string == string }
    }
}
