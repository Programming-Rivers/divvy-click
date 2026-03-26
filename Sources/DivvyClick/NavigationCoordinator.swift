import AppKit
import Combine

@MainActor
class NavigationCoordinator {
    let engine: NavigationEngine
    private let cursorEngine = CursorEngine()
    private var cancellables = Set<AnyCancellable>()

    private var autoScrollCancellable: AnyCancellable?
    private let autoScrollInterval: TimeInterval = 0.05
    private let autoScrollBaseDelta: Int32 = 20

    init(engine: NavigationEngine) {
        self.engine = engine
        setupObservers()
    }

    private func setupObservers() {
        // Active Sync: Whenever the region changes, jump the cursor to its center.
        engine.$currentRegion
            .sink { [weak self] region in
                guard let self = self, let r = region, self.engine.isActive else { return }
                
                // If it's a marker (0x0), jump to its origin and stop.
                if r.size == .zero {
                    self.cursorEngine.jump(to: CGRect(origin: r.origin, size: .zero))
                    self.engine.reset()
                    return
                }
                
                self.cursorEngine.jump(to: r)
            }
            .store(in: &cancellables)

        // Clear auto-scroll when navigation stops or layer changes
        engine.$isActive
            .sink { [weak self] active in
                if !active { self?.engine.autoScrollDirection = nil }
            }
            .store(in: &cancellables)
            
        engine.$activeLayer
            .sink { [weak self] _ in
                self?.engine.autoScrollDirection = nil
            }
            .store(in: &cancellables)

        // Handle Auto-Scroll Timer
        engine.$autoScrollDirection
            .sink { [weak self] direction in
                guard let self = self else { return }
                self.autoScrollCancellable = nil 
                
                if let dir = direction {
                    self.autoScrollCancellable = Timer.publish(every: self.autoScrollInterval, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            self.performAutoScroll(dir)
                        }
                } else {
                    self.engine.autoScrollSpeed = 0
                }
            }
            .store(in: &cancellables)
    }

    private func performAutoScroll(_ direction: NavigationEngine.ScrollDirection) {
        let delta = autoScrollBaseDelta * engine.autoScrollSpeed
        switch direction {
        case .up:    self.cursorEngine.scroll(deltaY: delta)
        case .down:  self.cursorEngine.scroll(deltaY: -delta)
        case .left:  self.cursorEngine.scroll(deltaX: -delta)
        case .right: self.cursorEngine.scroll(deltaX: delta)
        }
    }

    func execute(_ action: NavigationEngine.Action, flags: CGEventFlags = []) {
        guard let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)

        switch action {
        case .click:
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                self.cursorEngine.click(button: .left, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .doubleClick:
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.cursorEngine.click(button: .left, count: 2, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .rightClick:
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.cursorEngine.click(button: .right, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .middleClick:
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.cursorEngine.click(button: .center, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .move:
            if engine.isMouseDown {
                cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
            } else {
                self.engine.stop()
            }
        case .mouseDown:
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.cursorEngine.mouseDown(button: .left, flags: flags, at: targetPoint)
                self.engine.isMouseDown = true
                self.cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
                self.engine.start()
            }
        case .mouseUp:
            if engine.isMouseDown {
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            } else {
                cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
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
        case .autoScroll(let direction):
            if direction == nil {
                engine.autoScrollDirection = nil
                engine.autoScrollSpeed = 0
            } else if engine.autoScrollDirection == direction {
                // If same direction, increase speed (max 10)
                engine.autoScrollSpeed = min(engine.autoScrollSpeed + 1, 10)
            } else {
                // Switch direction or start new
                engine.autoScrollDirection = direction
                engine.autoScrollSpeed = 1
            }
        }
    }

    private func autoMoveIfDragging() {
        guard engine.isMouseDown, let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)
        cursorEngine.mouseDrag(button: .left, at: targetPoint)
    }
}
