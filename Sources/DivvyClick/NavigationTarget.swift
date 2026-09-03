import Foundation

public enum NavigationTarget: Equatable, Sendable {
    case region(CGRect)
    case restoreCursor(CGPoint)

    public var region: CGRect? {
        if case .region(let r) = self { return r }
        return nil
    }
}
