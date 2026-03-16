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

    /// Simulates a mouse click (down then up)
    func click(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = []) {
        mouseDown(button: button, count: count, flags: flags)
        mouseUp(button: button, count: count, flags: flags)
    }

    /// Presses the mouse button down
    func mouseDown(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = []) {
        postMouseEvent(type: mouseDownType(for: button), button: button, count: count, flags: flags)
    }

    /// Releases the mouse button
    func mouseUp(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = []) {
        postMouseEvent(type: mouseUpType(for: button), button: button, count: count, flags: flags)
    }

    /// Sends a mouse dragged event (useful for some apps during a drag)
    func mouseDrag(button: CGMouseButton = .left, flags: CGEventFlags = []) {
        postMouseEvent(type: mouseDragType(for: button), button: button, flags: flags)
    }

    /// Simulates a scroll wheel event.
    func scroll(deltaX: Int32 = 0, deltaY: Int32 = 0, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        // wheelCount = 2 when both vertical and horizontal are potentially used
        let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    private func postMouseEvent(type: CGEventType, button: CGMouseButton, count: Int = 1, flags: CGEventFlags = []) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main else { return }
        let cgLoc = CGPoint(x: mouseLoc.x, y: screen.frame.height - mouseLoc.y)

        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: cgLoc, mouseButton: button)
        
        event?.flags = flags

        if count > 1 {
            event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        }

        event?.post(tap: .cghidEventTap)
    }

    private func mouseDownType(for button: CGMouseButton) -> CGEventType {
        switch button {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        default: return .otherMouseDown
        }
    }

    private func mouseUpType(for button: CGMouseButton) -> CGEventType {
        switch button {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        default: return .otherMouseUp
        }
    }

    private func mouseDragType(for button: CGMouseButton) -> CGEventType {
        switch button {
        case .left: return .leftMouseDragged
        case .right: return .rightMouseDragged
        default: return .otherMouseDragged
        }
    }
}
