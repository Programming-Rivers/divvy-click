import AppKit
import CoreGraphics
import Foundation

struct CursorEngine {
    /// Jumps the cursor to the center of a target region
    @discardableResult
    func jump(to rect: CGRect) -> Bool {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Convert AppKit (bottom-left) coordinates to CG (top-left)
        guard let screen = NSScreen.main else { return false }
        let cgLocation = CGPoint(x: center.x, y: screen.frame.height - center.y)

        CGWarpMouseCursorPosition(cgLocation)
        return true
    }

    /// Simulates a mouse click at the current location
    func click(button: CGMouseButton = .left, count: Int = 1) {
        let mouseLoc = NSEvent.mouseLocation

        // Find the screen containing the mouse to calculate correct CG coordinates
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main else { return }
        let cgLoc = CGPoint(x: mouseLoc.x, y: screen.frame.height - mouseLoc.y)

        let source = CGEventSource(stateID: .hidSystemState)

        let downType: CGEventType = (button == .left) ? .leftMouseDown : (button == .right ? .rightMouseDown : .otherMouseDown)
        let upType: CGEventType = (button == .left) ? .leftMouseUp : (button == .right ? .rightMouseUp : .otherMouseUp)

        let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: cgLoc, mouseButton: button)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: cgLoc, mouseButton: button)

        if count > 1 {
            downEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            upEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        }

        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
}
