import AppKit

/// Abstracts access to screen information.
protocol ScreenProviding {
    var screens: [CGRect] { get }
    var mouseLocation: CGPoint { get }

    func screenFrame(at location: CGPoint) -> CGRect?
}

extension ScreenProviding {
    func screenFrame(at location: CGPoint) -> CGRect? {
        screens.first { NSMouseInRect(location, $0, false) }
    }
}

/// Default implementation that delegates to the real system APIs.
struct SystemScreenProvider: ScreenProviding {
    var screens: [CGRect] { NSScreen.screens.map { $0.frame } }
    var mouseLocation: CGPoint { NSEvent.mouseLocation }
}
