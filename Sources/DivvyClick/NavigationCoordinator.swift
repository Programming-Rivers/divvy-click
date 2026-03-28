import AppKit
import Combine

@MainActor
class NavigationCoordinator {
    let engine: NavigationEngine
    private let cursorEngine: CursorProviding
    private var cancellables = Set<AnyCancellable>()

    private var autoScrollCancellable: AnyCancellable?
    private var actionTask: Task<Void, Never>?
    private let autoScrollInterval: TimeInterval = AppConstants.autoScrollInterval
    private let autoScrollBaseDelta: Int32 = AppConstants.autoScrollBaseDelta

    init(engine: NavigationEngine, cursorEngine: CursorProviding = CursorEngine()) {
        self.engine = engine
        self.cursorEngine = cursorEngine
        setupObservers()
    }

    private func setupObservers() {
        // Active Sync: Whenever the target changes, jump the cursor to its center.
        engine.$currentTarget
            .sink { [weak self] target in
                guard let self = self, let t = target, self.engine.isActive else { return }
                
                switch t {
                case .restoreCursor(let point):
                    self.cursorEngine.jump(to: CGRect(origin: point, size: .zero))
                    DispatchQueue.main.async { [weak self] in
                        self?.engine.reset()
                    }
                case .region(let r):
                    self.cursorEngine.jump(to: r)
                }
            }
            .store(in: &cancellables)

        // Clear auto-scroll when navigation stops or layer changes
        engine.$isActive
            .sink { [weak self] active in
                if !active { 
                    self?.engine.scrollState.autoScrollDirection = nil 
                    self?.actionTask?.cancel()
                }
            }
            .store(in: &cancellables)
            
        engine.layerState.$activeLayer
            .sink { [weak self] _ in
                self?.engine.scrollState.autoScrollDirection = nil
            }
            .store(in: &cancellables)

        // Handle Auto-Scroll Timer
        engine.scrollState.$autoScrollDirection
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
                    self.engine.scrollState.autoScrollSpeed = 0
                }
            }
            .store(in: &cancellables)

        // Stop navigation if display configuration changes (e.g. monitor unplugged)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self = self, self.engine.isActive else { return }
                self.engine.stop()
            }
            .store(in: &cancellables)
    }

    private func performAutoScroll(_ direction: NavigationEngine.ScrollDirection) {
        let delta = autoScrollBaseDelta * engine.scrollState.autoScrollSpeed
        switch direction {
        case .up:    self.cursorEngine.scroll(deltaY: delta)
        case .down:  self.cursorEngine.scroll(deltaY: -delta)
        case .left:  self.cursorEngine.scroll(deltaX: -delta)
        case .right: self.cursorEngine.scroll(deltaX: delta)
        }
    }

    func execute(_ action: NavigationEngine.Action, flags: CGEventFlags = []) {
        actionTask?.cancel()
        
        guard let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)

        let clickDelay = AppConstants.clickDelay

        switch action {
        case .click:
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self, self.engine.isActive else { return }
                self.cursorEngine.click(button: .left, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .doubleClick:
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self, self.engine.isActive else { return }
                self.cursorEngine.click(button: .left, count: 2, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .rightClick:
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self, self.engine.isActive else { return }
                self.cursorEngine.click(button: .right, flags: flags, at: targetPoint)
                self.engine.stop()
            }
        case .middleClick:
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self, self.engine.isActive else { return }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self, self.engine.isActive else { return }
                self.cursorEngine.mouseDown(button: .left, flags: flags, at: targetPoint)
                self.engine.isMouseDown = true
                self.cursorEngine.mouseDrag(button: .left, flags: flags, at: targetPoint)
                // We keep the engine active for dragging
                self.engine.start() 
            }
        case .mouseUp:
            DispatchQueue.main.asyncAfter(deadline: .now() + clickDelay) { [weak self] in
                guard let self = self else { return }
                self.cursorEngine.mouseUp(button: .left, flags: flags, at: targetPoint)
                self.engine.isMouseDown = false
                self.engine.reset()
                self.engine.start()
            }
        case .scroll(let direction):
            let delta: Int32 = AppConstants.scrollStepDelta
            switch direction {
            case .up:    self.cursorEngine.scroll(deltaY: delta, flags: flags)
            case .down:  self.cursorEngine.scroll(deltaY: -delta, flags: flags)
            case .left:  self.cursorEngine.scroll(deltaX: -delta, flags: flags)
            case .right: self.cursorEngine.scroll(deltaX: delta, flags: flags)
            }
        case .autoScroll(let direction):
            if direction == nil {
                engine.scrollState.autoScrollDirection = nil
                engine.scrollState.autoScrollSpeed = 0
            } else if engine.scrollState.autoScrollDirection == direction {
                // If same direction, increase speed (max 10)
                engine.scrollState.autoScrollSpeed = min(engine.scrollState.autoScrollSpeed + 1, 10)
            } else {
                // Switch direction or start new
                engine.scrollState.autoScrollDirection = direction
                engine.scrollState.autoScrollSpeed = 1
            }
        }
    }

    private func autoMoveIfDragging() {
        guard engine.isMouseDown, let region = engine.currentRegion else { return }
        let targetPoint = CGPoint(x: region.midX, y: region.midY)
        cursorEngine.mouseDrag(button: .left, at: targetPoint)
    }
}
