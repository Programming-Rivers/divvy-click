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
        engine.vennfurcate(.up)
        let regionBeforeStop = engine.currentRegion

        engine.stop()

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.currentRegion, regionBeforeStop, "Region should be preserved after stop")
    }

    func testStartAfterStopResumesFromLastRegion() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.left)
        let regionAfterNav = engine.currentRegion

        engine.stop()
        engine.start()

        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.currentRegion, regionAfterNav, "Should resume from last region, not full screen")
    }

    func testResetClearsEverything() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.up)
        engine.layerState.activeLayer = .management

        engine.reset()

        XCTAssertFalse(engine.isActive)
        XCTAssertNil(engine.currentRegion)
        XCTAssertNil(engine.layerState.activeLayer)
    }

    func testStopResetsActiveLayer() {
        let engine = makeEngine()
        engine.start()
        engine.layerState.activeLayer = .action

        engine.stop()

        XCTAssertNil(engine.layerState.activeLayer)
    }

    func testStartResetsActiveLayer() {
        let engine = makeEngine()
        engine.layerState.activeLayer = .scroll

        engine.start()

        XCTAssertNil(engine.layerState.activeLayer)
    }

    // MARK: - Vennfurcate Tests

    func testVennfurcateShrinksByApproximatelyOneHalf() {
        let engine = makeEngine()
        engine.start()
        let originalRegion = engine.currentRegion!

        engine.vennfurcate(.up)

        let newRegion = engine.currentRegion!
        let expectedHeight = (originalRegion.height / 2.0) * 1.1

        XCTAssertEqual(newRegion.width, originalRegion.width, accuracy: 0.01)
        XCTAssertEqual(newRegion.height, expectedHeight, accuracy: 0.01)
    }

    func testVennfurcateUpAnchorsToTop() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.up)

        let result = engine.currentRegion!
        // macOS: origin is bottom-left, so "up" means x stays full width, y goes to top
        XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.01, "X should stay full width")
        XCTAssertGreaterThan(result.origin.y, original.origin.y, "Y should be at the top (higher in macOS coords)")
    }

    func testVennfurcateDownAnchorsToBottom() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.down)

        let result = engine.currentRegion!
        let expectedHeight = (original.height / 2.0) * 1.1

        XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.01, "X should stay full width")
        XCTAssertEqual(result.origin.y, original.origin.y, accuracy: 0.01, "Y should anchor to bottom")
        XCTAssertEqual(result.height, expectedHeight, accuracy: 0.01)
    }

    func testVennfurcateLeftAnchorsToLeft() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.left)

        let result = engine.currentRegion!
        let expectedWidth = (original.width / 2.0) * 1.1

        XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.01, "X should anchor to left")
        XCTAssertEqual(result.origin.y, original.origin.y, accuracy: 0.01, "Y should stay full height")
        XCTAssertEqual(result.width, expectedWidth, accuracy: 0.01)
    }

    func testVennfurcateAllFourDirections() {
        // Ensure every direction produces a valid sub-region within the parent
        let directions: [NavigationEngine.Direction] = [.up, .down, .left, .right]

        for direction in directions {
            let engine = makeEngine()
            engine.start()
            let original = engine.currentRegion!

            engine.vennfurcate(direction)

            let result = engine.currentRegion!
            XCTAssertTrue(result.width < original.width || result.height < original.height, "Region should shrink for \(direction)")
        }
    }

    func testVennfurcateConvergesTowardPoint() {
        let engine = makeEngine()
        engine.start()

        // Navigate alternating up/left 15 times — region should get very small
        for _ in 0..<15 {
            engine.vennfurcate(.up)
            engine.vennfurcate(.left)
        }

        let result = engine.currentRegion!
        XCTAssertLessThan(result.width, 1.0, "After 15 navigations, width should be sub-pixel")
        XCTAssertLessThan(result.height, 1.0, "After 15 navigations, height should be sub-pixel")
    }

    func testVennfurcateIsNoOpWhenInactive() {
        let engine = makeEngine()
        // Don't call start()
        engine.vennfurcate(.up)

        XCTAssertNil(engine.currentRegion)
    }

    // MARK: - Undo / Redo Tests

    func testUndoRestoresPreviousRegion() {
        let engine = makeEngine()
        engine.start()
        let original = engine.currentRegion!

        engine.vennfurcate(.up)
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

        engine.vennfurcate(.up)
        let afterNav = engine.currentRegion!
        engine.undo()
        engine.redo()

        XCTAssertEqual(engine.currentRegion, afterNav)
    }

    func testVennfurcateAfterUndoClearsRedoStack() {
        let engine = makeEngine()
        engine.start()

        engine.vennfurcate(.up)
        engine.undo()
        engine.vennfurcate(.down)

        // Redo should now be empty, so redo is a no-op
        let beforeRedo = engine.currentRegion
        engine.redo()
        XCTAssertEqual(engine.currentRegion, beforeRedo, "Redo stack should be cleared after new navigation")
    }

    func testUndoReactivatesEngine() {
        let engine = makeEngine()
        engine.start()
        engine.vennfurcate(.up)
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
            engine.vennfurcate(.up)
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

    func testPhysicalScreenMappingGaplessCompression() {
        // Arrange: 1 screen on top, 3 screens on bottom (T-shape)
        let screenTop = CGRect(x: 1920, y: 1080, width: 2560, height: 1440)
        let screenBottomLeft = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let screenBottomMid = CGRect(x: 1920, y: -360, width: 2560, height: 1440)
        let screenBottomRight = CGRect(x: 4480, y: 0, width: 1920, height: 1080)
        
        let provider = MockScreenProvider(screens: [screenTop, screenBottomLeft, screenBottomMid, screenBottomRight])
        let engine = NavigationEngine(screenProvider: provider)
        
        // Act
        let mapping = engine.screenMapping()
        
        // Assert: I(1)=Top, J(3)=BottomLeft, K(4)=BottomMid, L(5)=BottomRight
        XCTAssertEqual(mapping[1], screenTop)
        XCTAssertEqual(mapping[3], screenBottomLeft)
        XCTAssertEqual(mapping[4], screenBottomMid)
        XCTAssertEqual(mapping[5], screenBottomRight)
    }

    // MARK: - Layout Switching Tests

    func testRuntimeLayoutSwitching() {
        let registry = LayoutRegistry()
        let provider = makeMockProvider()
        let engine = NavigationEngine(screenProvider: provider, layoutRegistry: registry)
        
        // Default layout is OverlappingPairsLayout
        XCTAssertEqual(registry.activeLayout.id, "overlapping_pairs")

        // Switch to 3x3 Grid
        registry.selectLayout(byId: "grid_3x3")
        XCTAssertEqual(registry.activeLayout.id, "grid_3x3")
        XCTAssertEqual(registry.activeLayout.name, "3x3 Grid (UIO/JKL/M,.)")

        engine.start()
        engine.vennfurcate(.center)
        let region = engine.currentRegion!
        let expectedWidth = (1920.0 / 3.0) * 1.1
        XCTAssertEqual(region.width, expectedWidth, accuracy: 0.01)

        // Switch back
        registry.selectLayout(byId: "overlapping_pairs")
        XCTAssertEqual(registry.activeLayout.id, "overlapping_pairs")
    }

    func testGrid3x3Subdivision() {
        let gridLayout = Grid3x3Layout()
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let centerRegion = gridLayout.subdivide(region: screen, tileId: "center", screenFrame: screen)
        let expectedWidth = (screen.width / 3.0) * 1.1
        let expectedHeight = (screen.height / 3.0) * 1.1

        XCTAssertEqual(centerRegion.width, expectedWidth, accuracy: 0.01)
        XCTAssertEqual(centerRegion.height, expectedHeight, accuracy: 0.01)
        XCTAssertEqual(centerRegion.midX, screen.midX, accuracy: 0.01)
        XCTAssertEqual(centerRegion.midY, screen.midY, accuracy: 0.01)
    }

    func testProspectiveTargetPointsForGrid3x3() {
        let gridLayout = Grid3x3Layout()
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let prospectivePoints = gridLayout.prospectiveTargetPoints(for: screen, screenFrame: screen)
        // 3x3 layout has 9 tiles, center matches current center so 8 prospective endpoints are returned
        XCTAssertEqual(prospectivePoints.count, 8)

        let currentCenter = CGPoint(x: screen.midX, y: screen.midY)
        for pt in prospectivePoints {
            // All prospective points should be strictly inside screen bounds
            XCTAssertTrue(screen.contains(pt))
            // None should be the current center
            XCTAssertGreaterThan(hypot(pt.x - currentCenter.x, pt.y - currentCenter.y), 1.0)
        }
    }

    func testProspectiveTargetPointsForOverlappingPairs() {
        let pairsLayout = OverlappingPairsLayout()
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let prospectivePoints = pairsLayout.prospectiveTargetPoints(for: screen, screenFrame: screen)
        // 2x2 overlapping pairs layout has 4 tiles (up, down, left, right)
        XCTAssertEqual(prospectivePoints.count, 4)

        let currentCenter = CGPoint(x: screen.midX, y: screen.midY)
        for pt in prospectivePoints {
            XCTAssertTrue(screen.contains(pt))
            XCTAssertGreaterThan(hypot(pt.x - currentCenter.x, pt.y - currentCenter.y), 1.0)
        }
    }
}
