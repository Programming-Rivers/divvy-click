import XCTest
import CoreGraphics
@testable import Sources_DivvyClick_lib

@MainActor
final class NavigationCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) -> (NavigationCoordinator, NavigationEngine, MockCursorEngine) {
        let screenProvider = MockScreenProvider(screenFrame: screenFrame, mouseLocation: mouseLocation)
        let engine = NavigationEngine(screenProvider: screenProvider)
        let cursorEngine = MockCursorEngine()
        let coordinator = NavigationCoordinator(engine: engine, cursorEngine: cursorEngine)
        return (coordinator, engine, cursorEngine)
    }

    private func drainMainQueue(for interval: TimeInterval = 0.1) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
    }

    // MARK: - 1. Cursor Sync on Target Changes

    func testStartJumpsCursorToScreenCenter() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        _ = coordinator
        
        engine.start()

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .jump(CGRect(x: 0, y: 0, width: 1920, height: 1080)))
    }

    func testVennfurcateJumpsCursorToNewRegion() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        _ = coordinator
        engine.start()
        cursorEngine.calls.removeAll()

        engine.vennfurcate(.up)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard let region = engine.currentRegion else {
            XCTFail("Engine should have a currentRegion")
            return
        }
        XCTAssertEqual(cursorEngine.calls.first?.kind, .jump(region))
    }

    func testRestoreCursorTargetJumpsToPointAndResets() {
        let (coordinator, engine, cursorEngine) = makeCoordinator(mouseLocation: CGPoint(x: 100, y: 200))
        _ = coordinator
        engine.start()
        cursorEngine.calls.removeAll()

        // Undo down to initial restoreCursor target
        _ = engine.undo()

        // Drain run loop to process async reset
        drainMainQueue(for: 0.05)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .jump(CGRect(origin: CGPoint(x: 100, y: 200), size: .zero)))
        XCTAssertFalse(engine.isActive)
    }

    func testTargetChangeWhileDraggingSendsDrag() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        _ = coordinator
        engine.start()
        cursorEngine.calls.removeAll()

        engine.isMouseDown = true
        engine.vennfurcate(.left)

        guard let region = engine.currentRegion else {
            XCTFail("Engine should have a currentRegion")
            return
        }
        let expectedTargetPoint = CGPoint(x: region.midX, y: region.midY)
        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .mouseDrag(.left, expectedTargetPoint))
    }

    // MARK: - 2. Click Actions

    func testClickSendsLeftClickAndStops() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.click)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .click(let button, let count, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected click call")
            return
        }
        XCTAssertEqual(button, .left)
        XCTAssertEqual(count, 1)
        XCTAssertFalse(engine.isActive)
    }

    func testDoubleClickSendsCountTwo() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.doubleClick)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .click(let button, let count, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected double click call")
            return
        }
        XCTAssertEqual(button, .left)
        XCTAssertEqual(count, 2)
        XCTAssertFalse(engine.isActive)
    }

    func testRightClickSendsRightButton() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.rightClick)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .click(let button, let count, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected right click call")
            return
        }
        XCTAssertEqual(button, .right)
        XCTAssertEqual(count, 1)
        XCTAssertFalse(engine.isActive)
    }

    func testMiddleClickSendsCenterButton() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.middleClick)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .click(let button, let count, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected middle click call")
            return
        }
        XCTAssertEqual(button, .center)
        XCTAssertEqual(count, 1)
        XCTAssertFalse(engine.isActive)
    }

    func testClickPassesThroughFlags() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        let testFlags: CGEventFlags = [.maskShift]
        coordinator.execute(.click, flags: testFlags)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertTrue(cursorEngine.calls.first?.flags.contains(.maskShift) == true)
    }

    func testClickIsNoOpWithNoRegion() {
        let (coordinator, _, cursorEngine) = makeCoordinator()
        // Engine is not started, so currentRegion is nil
        coordinator.execute(.click)
        drainMainQueue(for: 0.1)

        XCTAssertTrue(cursorEngine.calls.isEmpty)
    }

    // MARK: - 3. Drag Lifecycle

    func testMouseDownSetsDownStateAndSendsDrag() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.mouseDown)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 2)
        guard case .mouseDown(.left, 1, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected mouseDown call first")
            return
        }
        guard case .mouseDrag(.left, _) = cursorEngine.calls.last?.kind else {
            XCTFail("Expected mouseDrag call second")
            return
        }
        XCTAssertTrue(engine.isMouseDown)
        XCTAssertTrue(engine.isActive)
    }

    func testMouseUpReleasesAndResets() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        engine.isMouseDown = true
        cursorEngine.calls.removeAll()

        coordinator.execute(.mouseUp)
        drainMainQueue(for: 0.1)

        XCTAssertEqual(cursorEngine.calls.count, 2)
        guard case .mouseUp(.left, 1, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected mouseUp call")
            return
        }
        guard case .jump = cursorEngine.calls.last?.kind else {
            XCTFail("Expected jump call on restart")
            return
        }
        XCTAssertFalse(engine.isMouseDown)
        XCTAssertTrue(engine.isActive)
    }

    func testMoveWhileDraggingSendsDrag() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        engine.isMouseDown = true
        cursorEngine.calls.removeAll()

        coordinator.execute(.move)

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .mouseDrag(.left, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected mouseDrag call")
            return
        }
    }

    func testMoveWithoutDragStopsEngine() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.move)

        XCTAssertFalse(engine.isActive)
        XCTAssertTrue(cursorEngine.calls.isEmpty)
    }

    // MARK: - 4. Scroll Actions

    func testScrollUpSendsPositiveDeltaY() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.scroll(.up))

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .scroll(0, AppConstants.scrollStepDelta))
    }

    func testScrollDownSendsNegativeDeltaY() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.scroll(.down))

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .scroll(0, -AppConstants.scrollStepDelta))
    }

    func testScrollLeftSendsNegativeDeltaX() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.scroll(.left))

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .scroll(-AppConstants.scrollStepDelta, 0))
    }

    func testScrollRightSendsPositiveDeltaX() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.scroll(.right))

        XCTAssertEqual(cursorEngine.calls.count, 1)
        XCTAssertEqual(cursorEngine.calls.first?.kind, .scroll(AppConstants.scrollStepDelta, 0))
    }

    func testAutoScrollStartsSetsDirectionAndSpeed() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))

        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 1)
    }

    func testAutoScrollSameDirectionIncrementsSpeed() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))
        coordinator.execute(.autoScroll(.up))

        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 2)
    }

    func testAutoScrollSpeedCapsAtTen() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        for _ in 0..<15 {
            coordinator.execute(.autoScroll(.up))
        }

        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 10)
    }

    func testAutoScrollNilStopsAndResetsSpeed() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))
        coordinator.execute(.autoScroll(nil))

        XCTAssertNil(engine.scrollState.autoScrollDirection)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 0)
    }

    func testAutoScrollDirectionChangeSwitches() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))
        coordinator.execute(.autoScroll(.down))

        XCTAssertEqual(engine.scrollState.autoScrollDirection, .down)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 1)
    }

    func testAutoScrollTimerPerformsScrollTicks() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.autoScroll(.up))

        // Drain run loop for 100ms so timer fires ticks
        drainMainQueue(for: 0.1)

        // Verify that scroll ticks were recorded
        let scrollCalls = cursorEngine.calls.filter {
            if case .scroll(let dx, let dy) = $0.kind {
                return dx == 0 && dy == AppConstants.autoScrollBaseDelta
            }
            return false
        }
        XCTAssertGreaterThanOrEqual(scrollCalls.count, 1)

        // Stop auto scroll
        coordinator.execute(.autoScroll(nil))
    }

    // MARK: - 5. Deactivation Cleanup

    func testStopClearsAutoScrollDirection() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)

        engine.stop()

        XCTAssertNil(engine.scrollState.autoScrollDirection)
    }

    func testStopWhileDraggingSendsMouseUp() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        _ = coordinator
        engine.start()
        engine.isMouseDown = true
        cursorEngine.calls.removeAll()

        engine.stop()

        XCTAssertEqual(cursorEngine.calls.count, 1)
        guard case .mouseUp(.left, 1, _) = cursorEngine.calls.first?.kind else {
            XCTFail("Expected mouseUp call on stop when dragging")
            return
        }
    }

    func testLayerChangeClearsAutoScroll() {
        let (coordinator, engine, _) = makeCoordinator()
        engine.start()

        coordinator.execute(.autoScroll(.up))
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)

        engine.layerState.activeLayer = .scroll

        XCTAssertNil(engine.scrollState.autoScrollDirection)
    }

    // MARK: - 6. Edge Cases

    func testClickWhileInactiveIsSkipped() {
        let (coordinator, engine, cursorEngine) = makeCoordinator()
        engine.start()
        cursorEngine.calls.removeAll()

        coordinator.execute(.click)
        // Stop engine immediately before the 50ms asyncAfter delay fires
        engine.stop()

        drainMainQueue(for: 0.1)

        XCTAssertTrue(cursorEngine.calls.isEmpty)
    }
}
