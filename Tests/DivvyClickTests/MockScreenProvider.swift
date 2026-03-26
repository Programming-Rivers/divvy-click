import AppKit
@testable import Sources_DivvyClick_lib

/// A mock screen provider for deterministic testing.
/// Uses a single virtual screen with a configurable frame and mouse location.
struct MockScreenProvider: ScreenProviding {
    private let _screens: [CGRect]
    private let _mouseLocation: CGPoint

    init(
        screens: [CGRect] = [CGRect(x: 0, y: 0, width: 1920, height: 1080)],
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) {
        self._screens = screens
        self._mouseLocation = mouseLocation
    }

    init(
        screenFrame: CGRect,
        mouseLocation: CGPoint
    ) {
        self._screens = [screenFrame]
        self._mouseLocation = mouseLocation
    }

    var screens: [CGRect] {
        _screens
    }

    var mouseLocation: CGPoint { _mouseLocation }

    func screenFrame(at location: CGPoint) -> CGRect? {
        _screens.first { NSMouseInRect(location, $0, false) }
    }
}
