import AppKit
@testable import Sources_DivvyClick_lib

/// A mock screen provider for deterministic testing.
/// Uses a single virtual screen with a configurable frame and mouse location.
struct MockScreenProvider: ScreenProviding {
    private let _screenFrame: CGRect
    private let _mouseLocation: CGPoint

    init(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) {
        self._screenFrame = screenFrame
        self._mouseLocation = mouseLocation
    }

    var screens: [CGRect] {
        [_screenFrame]
    }

    var mouseLocation: CGPoint { _mouseLocation }

    func screenFrame(at location: CGPoint) -> CGRect? {
        _screenFrame
    }
}
