import XCTest
@testable import Sources_DivvyClick_lib

@MainActor
final class NavigationEngineTests: XCTestCase {

    // MARK: - Helpers

    /// A mock screen provider with a single 1920x1080 screen.
    private func makeMockProvider(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) -> MockScreenProvider {
        MockScreenProvider(screenFrame: screenFrame, mouseLocation: mouseLocation)
    }

    private func makeEngine(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) -> NavigationEngine {
        let provider = makeMockProvider(screenFrame: screenFrame, mouseLocation: mouseLocation)
        return NavigationEngine(screenProvider: provider)
    }

    // MARK: - Lifecycle Tests

    func testStartActivatesEngine() {
        let engine = makeEngine()
        XCTAssertFalse(engine.isActive)
        XCTAssertNil(engine.currentRegion)

        engine.start()

        XCTAssertTrue(engine.isActive)
        XCTAssertNotNil(engine.currentRegion)
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testStopDeactivatesButPreservesRegion() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.topLeft)
        let regionBeforeStop = engine.currentRegion

        engine.stop()

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.currentRegion, regionBeforeStop, "Region should be preserved after stop")
    }

    func testStartAfterStopResumesFromLastRegion() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.center)
        let regionAfterNav = engine.currentRegion

        engine.stop()
        engine.start()

        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.currentRegion, regionAfterNav, "Should resume from last region, not full screen")
    }

    func testResetClearsEverything() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.topLeft)

        engine.reset()

        XCTAssertFalse(engine.isActive)
        XCTAssertNil(engine.currentRegion)
    }

    // MARK: - Vennfurcate Tests

    func testVennfurcateShrinksByApproximatelyOneThird() {
        let engine = makeEngine()
        engine.start()
        let originalRegion = engine.currentRegion!

        engine.vennfurcate(.center)

        let newRegion = engine.currentRegion!
        let expectedWidth = (originalRegion.width / 3.0) * 1.1
        let expectedHeight = (originalRegion.height / 3.0) * 1.1

        XCTAssertEqual(newRegion.width, expectedWidth, accuracy: 0.01)
        XCTAssertEqual(newRegion.height, expectedHeight, accuracy: 0.01)
    }

    func testVennfurcateTopLeftAnchorsToTopLeft() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.topLeft)

        let result = engine.currentRegion!
        // macOS: origin is bottom-left, so "top-left" means x stays, y goes up
        XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.01, "X should anchor to left")
        XCTAssertGreaterThan(result.origin.y, original.origin.y, "Y should be at the top (higher in macOS coords)")
    }

    func testVennfurcateBottomRightAnchorsToBottomRight() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.bottomRight)

        let result = engine.currentRegion!
        let expectedWidth = (original.width / 3.0) * 1.1

        XCTAssertEqual(result.origin.x, original.origin.x + original.width - expectedWidth, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, original.origin.y, accuracy: 0.01, "Y should anchor to bottom")
    }

    func testVennfurcateCenterIsCentered() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.center)

        let result = engine.currentRegion!
        XCTAssertEqual(result.midX, original.midX, accuracy: 0.01, "Center should preserve midX")
        XCTAssertEqual(result.midY, original.midY, accuracy: 0.01, "Center should preserve midY")
    }

    func testVennfurcateAllNineDirections() {
        // Ensure every direction produces a valid sub-region within the parent
        let directions: [NavigationEngine.Direction] = [
            .topLeft, .up, .topRight,
            .left, .center, .right,
            .bottomLeft, .down, .bottomRight
        ]

        for direction in directions {
            let engine = makeEngine()
            engine.start()
            let original = engine.currentRegion!

            engine.vennfurcate(direction)

            let result = engine.currentRegion!
            XCTAssertLessThan(result.width, original.width, "Width should shrink for \(direction)")
            XCTAssertLessThan(result.height, original.height, "Height should shrink for \(direction)")
        }
    }

    func testVennfurcateConvergesTowardPoint() {
        let engine = makeEngine()
        engine.start()

        // Navigate center 10 times — region should get very small
        for _ in 0..<10 {
            engine.vennfurcate(.center)
        }

        let result = engine.currentRegion!
        XCTAssertLessThan(result.width, 1.0, "After 10 center navigations, width should be sub-pixel")
        XCTAssertLessThan(result.height, 1.0, "After 10 center navigations, height should be sub-pixel")
    }

    func testVennfurcateIsNoOpWhenInactive() {
        let engine = makeEngine()
        // Don't call start()
        engine.vennfurcate(.center)

        XCTAssertNil(engine.currentRegion)
    }

    // MARK: - Undo / Redo Tests

    func testUndoRestoresPreviousRegion() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.topLeft)
        let undid = engine.undo()

        XCTAssertTrue(undid)
        XCTAssertEqual(engine.currentRegion, original)
    }

    func testUndoAtStartReturnsToMarkerThenFalse() {
        let engine = makeEngine()
        engine.start()

        // First undo returns to the initial mouse position marker
        XCTAssertTrue(engine.undo())
        // Second undo fails because the marker was the last item
        XCTAssertFalse(engine.undo())
    }

    func testRedoRestoresUndoneRegion() {
        let engine = makeEngine()
        engine.start()

        engine.vennfurcate(.topLeft)
        let afterNav = engine.currentRegion!
        engine.undo()
        engine.redo()

        XCTAssertEqual(engine.currentRegion, afterNav)
    }

    func testVennfurcateAfterUndoClearsRedoStack() {
        let engine = makeEngine()
        engine.start()

        engine.vennfurcate(.topLeft)
        engine.undo()
        engine.vennfurcate(.bottomRight)

        // Redo should now be empty, so redo is a no-op
        let beforeRedo = engine.currentRegion
        engine.redo()
        XCTAssertEqual(engine.currentRegion, beforeRedo, "Redo stack should be cleared after new navigation")
    }

    func testUndoReactivatesEngine() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.topLeft)
        engine.stop()

        let undid = engine.undo()

        XCTAssertTrue(undid)
        XCTAssertTrue(engine.isActive, "Undo should reactivate the engine")
    }

    func testHistoryStackIsCapped() {
        let engine = makeEngine()
        engine.start()

        // Navigate 150 times — well over the 100 cap
        for _ in 0..<150 {
            engine.vennfurcate(.center)
        }

        // Undo should succeed at most ~100 times
        var undoCount = 0
        while engine.undo() {
            undoCount += 1
        }
        XCTAssertLessThanOrEqual(undoCount, 100, "History should be capped at maxStackSize")
    }

    // MARK: - Display Selection Tests

    func testShowDisplaySelectionActivatesSelectionMode() {
        let engine = makeEngine()
        engine.showDisplaySelection()

        XCTAssertTrue(engine.isActive)
        XCTAssertTrue(engine.isSelectingDisplay)
    }

    func testStopClearsDisplaySelectionMode() {
        let engine = makeEngine()
        engine.showDisplaySelection()
        engine.stop()

        XCTAssertFalse(engine.isSelectingDisplay)
    }

    func testSelectDisplayOutOfBoundsIsNoOp() {
        let engine = makeEngine()
        engine.start()
        let regionBefore = engine.currentRegion
        
        engine.selectDisplay(at: 999)
        
        XCTAssertEqual(engine.currentRegion, regionBefore)
    }

    func testPhysicalScreenMapping() {
        // Arrange: 3 screens in a horizontal row
        let screenLeft = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let screenMid = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let screenRight = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        
        let provider = MockScreenProvider(screens: [screenMid, screenRight, screenLeft])
        let engine = NavigationEngine(screenProvider: provider)
        
        // Act
        let mapping = engine.screenMapping()
        
        // Assert: J(3)=Left, K(4)=Mid, L(5)=Right
        XCTAssertEqual(mapping[3], screenLeft)
        XCTAssertEqual(mapping[4], screenMid)
        XCTAssertEqual(mapping[5], screenRight)
    }
}
