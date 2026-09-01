import CoreGraphics
import Foundation
@testable import Sources_DivvyClick_lib

struct CursorCall: Equatable {
    enum Kind: Equatable {
        case jump(CGRect)
        case click(CGMouseButton, Int, CGPoint?)
        case mouseDown(CGMouseButton, Int, CGPoint?)
        case mouseUp(CGMouseButton, Int, CGPoint?)
        case mouseDrag(CGMouseButton, CGPoint?)
        case scroll(Int32, Int32)
    }

    let kind: Kind
    let flags: CGEventFlags

    static func == (lhs: CursorCall, rhs: CursorCall) -> Bool {
        return lhs.kind == rhs.kind && lhs.flags.rawValue == rhs.flags.rawValue
    }
}

class MockCursorEngine: CursorProviding {
    var calls: [CursorCall] = []

    private func record(_ call: CursorCall) {
        calls.append(call)
    }

    @discardableResult
    func jump(to rect: CGRect) -> Bool {
        record(CursorCall(kind: .jump(rect), flags: []))
        return true
    }

    func click(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?) {
        record(CursorCall(kind: .click(button, count, location), flags: flags))
    }

    func mouseDown(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?) {
        record(CursorCall(kind: .mouseDown(button, count, location), flags: flags))
    }

    func mouseUp(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?) {
        record(CursorCall(kind: .mouseUp(button, count, location), flags: flags))
    }

    func mouseDrag(button: CGMouseButton, flags: CGEventFlags, at location: CGPoint?) {
        record(CursorCall(kind: .mouseDrag(button, location), flags: flags))
    }

    func scroll(deltaX: Int32, deltaY: Int32, flags: CGEventFlags) {
        record(CursorCall(kind: .scroll(deltaX, deltaY), flags: flags))
    }
}
