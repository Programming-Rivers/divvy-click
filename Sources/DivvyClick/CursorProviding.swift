import CoreGraphics

protocol CursorProviding {
    @discardableResult
    func jump(to rect: CGRect) -> Bool
    
    func click(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?)
    func mouseDown(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?)
    func mouseUp(button: CGMouseButton, count: Int, flags: CGEventFlags, at location: CGPoint?)
    func mouseDrag(button: CGMouseButton, flags: CGEventFlags, at location: CGPoint?)
    func scroll(deltaX: Int32, deltaY: Int32, flags: CGEventFlags)
}

extension CursorProviding {
    func click(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        click(button: button, count: count, flags: flags, at: location)
    }

    func mouseDown(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        mouseDown(button: button, count: count, flags: flags, at: location)
    }

    func mouseUp(button: CGMouseButton = .left, count: Int = 1, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        mouseUp(button: button, count: count, flags: flags, at: location)
    }

    func mouseDrag(button: CGMouseButton = .left, flags: CGEventFlags = [], at location: CGPoint? = nil) {
        mouseDrag(button: button, flags: flags, at: location)
    }

    func scroll(deltaX: Int32 = 0, deltaY: Int32 = 0, flags: CGEventFlags = []) {
        scroll(deltaX: deltaX, deltaY: deltaY, flags: flags)
    }
}
