import AppKit
import CoreGraphics
import Foundation

struct CursorEngine {
    /// Jumps the cursor to the center of a target region
    @discardableResult
    func jump(to rect: CGRect) -> Bool {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let cgLocation = convertToCG(center)
        CGWarpMouseCursorPosition(cgLocation)
        return true
    }

    /// Simulates a mouse click (down then up)
    func click(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        mouseDown(button: button, count: count, flags: flags, at: location)
        mouseUp(button: button, count: count, flags: flags, at: location)
    }

    /// Presses the mouse button down
    func mouseDown(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        postMouseEvent(type: mouseDownType(for: button), button: button, count: count, flags: flags, at: location)
    }

    /// Releases the mouse button
    func mouseUp(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        postMouseEvent(type: mouseUpType(for: button), button: button, count: count, flags: flags, at: location)
    }

    /// Sends a mouse dragged event (useful for some apps during a drag)
    func mouseDrag(button: CGMouseButton = .left, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        postMouseEvent(type: mouseDragType(for: button), button: button, flags: flags, at: location)
    }

    /// Simulates a scroll wheel event.
    func scroll(deltaX: Int32 = 0, deltaY: Int32 = 0, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        // wheelCount = 2 when both vertical and horizontal are potentially used
        let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    private func convertToCG(_ point: CGPoint) -> CGPoint {
        // AppKit uses bottom-left origin. CoreGraphics uses top-left origin.
        // Both use the primary screen (screens[0]) as the reference point for (0,0).
        // To convert, we subtract the AppKit Y from the height of the primary screen.
        guard let primaryScreen = NSScreen.screens.first else { return point }
        return CGPoint(x: point.x, y: primaryScreen.frame.height - point.y)
    }

    private func postMouseEvent(type: CGEventType, button: CGMouseButton, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        let cgLoc: CGPoint
        if let location = location {
            cgLoc = convertToCG(location)
        } else {
            let mouseLoc = NSEvent.mouseLocation
            cgLoc = convertToCG(mouseLoc)
        }

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
