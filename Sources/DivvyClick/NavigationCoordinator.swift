import AppKit
import Combine

@MainActor
class NavigationCoordinator {
    let engine: NavigationEngine
    private let cursorEngine = CursorEngine()
    private var cancellables = Set<AnyCancellable>()

    init(engine: NavigationEngine) {
        self.engine = engine
        setupObservers()
    }

    private func setupObservers() {
        // Automatically perform a drag event when the region changes during a mouse-down session.
        // This decouples state management from the side-effect of moving the mouse.
        engine.$currentRegion
            .sink { [weak self] _ in
                self?.autoMoveIfDragging()
            }
            .store(in: &cancellables)
    }

    func execute(_ action: NavigationEngine.Action, flags: CGEventFlags = []) {
        guard let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)

        switch action {
        case .click:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .left, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .doubleClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .left, count: 2, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .rightClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .right, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .middleClick:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.click(button: .center, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .move:
            if engine.isMouseDown {
                cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
            } else {
                cursorEngine.jump(to: region)
                self.engine.stop()
            }
        case .mouseDown:
            cursorEngine.jump(to: region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.cursorEngine.mouseDown(button: .left, flags: flags, at: targetPoint)
                self.engine.isMouseDown = true
                self.cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
                self.engine.start()
            }
        case .mouseUp:
            if engine.isMouseDown {
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            } else {
                cursorEngine.jump(to: region)
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.engine.isMouseDown = false
                self.engine.reset()
                self.engine.start()
            }
        case .scroll(let direction):
            let delta: Int32 = 100
            switch direction {
            case .up:    self.cursorEngine.scroll(deltaY: delta, flags: flags)
            case .down:  self.cursorEngine.scroll(deltaY: -delta, flags: flags)
            case .left:  self.cursorEngine.scroll(deltaX: -delta, flags: flags)
            case .right: self.cursorEngine.scroll(deltaX: delta, flags: flags)
            }
        }
    }

    private func autoMoveIfDragging() {
        guard engine.isMouseDown, let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)
        cursorEngine.mouseDrag(button: .left, at: targetPoint)
    }
}
