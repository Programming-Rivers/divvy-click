import Foundation

enum NavigationTarget: Equatable {
    case region(CGRect)
    case restoreCursor(CGPoint)

    var region: CGRect? {
        if case .region(let r) = self { return r }
        return nil
    }
}
