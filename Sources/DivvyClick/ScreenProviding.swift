import AppKit

/// Abstracts access to screen information.
public protocol ScreenProviding {
    var screens: [CGRect] { get }
    var mouseLocation: CGPoint { get }

    func screenFrame(at location: CGPoint) -> CGRect?
}

public extension ScreenProviding {
    func screenFrame(at location: CGPoint) -> CGRect? {
        screens.first { NSMouseInRect(location, $0, false) }
    }
}

/// Default implementation that delegates to the real system APIs.
public struct SystemScreenProvider: ScreenProviding {
    public init() {}
    public var screens: [CGRect] { NSScreen.screens.map { $0.frame } }
    public var mouseLocation: CGPoint { NSEvent.mouseLocation }
}
