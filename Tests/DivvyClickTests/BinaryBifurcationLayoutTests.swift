import CoreGraphics
import DivvyClickCoordination
import DivvyClickCore
import DivvyClickEngine
import DivvyClickLayouts
import XCTest

@MainActor
final class BinaryBifurcationLayoutTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let layout = BinaryBifurcationLayout()

    // MARK: - Layout Identity & Metadata

    func testLayoutProperties() {
        XCTAssertEqual(layout.id, "binary_bifurcation")
        XCTAssertEqual(layout.name, "2-Tile Bifurcation (JK)")
        XCTAssertFalse(layout.description.isEmpty)
    }

    // MARK: - Alternating Orientation & Ratio

    func testAlternatingOrientationAcrossBifurcations() {
        // Step 0: Full screen (1920x1080) -> Horizontal
        let r0 = screen
        XCTAssertEqual(layout.orientation(for: r0, screenFrame: screen), .horizontal)

        // Step 1: Left tile (960x1080) -> Vertical
        let r1 = layout.subdivide(region: r0, tileId: "first", screenFrame: screen)
        XCTAssertEqual(r1.width, 960.0, accuracy: 0.001)
        XCTAssertEqual(r1.height, 1080.0, accuracy: 0.001)
        XCTAssertEqual(layout.orientation(for: r1, screenFrame: screen), .vertical)

        // Step 2: Top tile (960x540) -> Horizontal
        let r2 = layout.subdivide(region: r1, tileId: "first", screenFrame: screen)
        XCTAssertEqual(r2.width, 960.0, accuracy: 0.001)
        XCTAssertEqual(r2.height, 540.0, accuracy: 0.001)
        XCTAssertEqual(layout.orientation(for: r2, screenFrame: screen), .horizontal)

        // Step 3: Right tile (480x540) -> Vertical
        let r3 = layout.subdivide(region: r2, tileId: "second", screenFrame: screen)
        XCTAssertEqual(r3.width, 480.0, accuracy: 0.001)
        XCTAssertEqual(r3.height, 540.0, accuracy: 0.001)
        XCTAssertEqual(layout.orientation(for: r3, screenFrame: screen), .vertical)

        // Step 4: Bottom tile (480x270) -> Horizontal
        let r4 = layout.subdivide(region: r3, tileId: "second", screenFrame: screen)
        XCTAssertEqual(r4.width, 480.0, accuracy: 0.001)
        XCTAssertEqual(r4.height, 270.0, accuracy: 0.001)
        XCTAssertEqual(layout.orientation(for: r4, screenFrame: screen), .horizontal)
    }

    func testTileRatioSelfSimilarity() {
        // Full screen aspect ratio = 1920 / 1080 = 1.777...
        let screenRatio = screen.width / screen.height

        // After two bifurcations (one horizontal, one vertical), the ratio is identical
        let r1 = layout.subdivide(region: screen, tileId: "first", screenFrame: screen)
        let r2 = layout.subdivide(region: r1, tileId: "first", screenFrame: screen)

        let step2Ratio = r2.width / r2.height
        XCTAssertEqual(step2Ratio, screenRatio, accuracy: 0.001, "Aspect ratio after 2 bifurcations must match the screen ratio exactly")

        // Tiles in the same bifurcation have identical sizes
        let left = layout.subdivide(region: screen, tileId: "first", screenFrame: screen)
        let right = layout.subdivide(region: screen, tileId: "second", screenFrame: screen)
        XCTAssertEqual(left.size, right.size, "Both horizontal tiles must have identical size")

        let top = layout.subdivide(region: left, tileId: "first", screenFrame: screen)
        let bottom = layout.subdivide(region: left, tileId: "second", screenFrame: screen)
        XCTAssertEqual(top.size, bottom.size, "Both vertical tiles must have identical size")
    }

    // MARK: - Coordinate Subdivisions

    func testHorizontalSubdivisionCoordinates() {
        // First / Left
        let left = layout.subdivide(region: screen, tileId: "first", screenFrame: screen)
        XCTAssertEqual(left, CGRect(x: 0, y: 0, width: 960, height: 1080))

        // Second / Right
        let right = layout.subdivide(region: screen, tileId: "second", screenFrame: screen)
        XCTAssertEqual(right, CGRect(x: 960, y: 0, width: 960, height: 1080))
    }

    func testVerticalSubdivisionCoordinates() {
        let leftHalf = CGRect(x: 0, y: 0, width: 960, height: 1080)

        // In macOS coordinates (bottom-left origin):
        // Top tile: origin.y = 540, height = 540
        let top = layout.subdivide(region: leftHalf, tileId: "first", screenFrame: screen)
        XCTAssertEqual(top, CGRect(x: 0, y: 540, width: 960, height: 540))

        // Bottom tile: origin.y = 0, height = 540
        let bottom = layout.subdivide(region: leftHalf, tileId: "second", screenFrame: screen)
        XCTAssertEqual(bottom, CGRect(x: 0, y: 0, width: 960, height: 540))
    }

    // MARK: - Key Cues & Target Points

    func testKeyCuesHorizontalAndVertical() {
        // Horizontal key cues
        let cuesH = layout.keyCues(localRegion: screen, screenFrame: screen)
        XCTAssertEqual(cuesH.count, 2)
        XCTAssertEqual(cuesH[0].key, "J")
        XCTAssertEqual(cuesH[0].x, screen.width * 0.25, accuracy: 0.001)
        XCTAssertEqual(cuesH[0].y, screen.midY, accuracy: 0.001)
        XCTAssertEqual(cuesH[1].key, "K")
        XCTAssertEqual(cuesH[1].x, screen.width * 0.75, accuracy: 0.001)
        XCTAssertEqual(cuesH[1].y, screen.midY, accuracy: 0.001)

        // Vertical key cues (localRegion: 960x1080)
        let verticalLocalRegion = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let cuesV = layout.keyCues(localRegion: verticalLocalRegion, screenFrame: screen)
        XCTAssertEqual(cuesV.count, 2)
        XCTAssertEqual(cuesV[0].key, "J")
        XCTAssertEqual(cuesV[0].x, 480.0, accuracy: 0.001)
        XCTAssertEqual(cuesV[0].y, 1080.0 * 0.25, accuracy: 0.001) // Visual top in SwiftUI
        XCTAssertEqual(cuesV[1].key, "K")
        XCTAssertEqual(cuesV[1].x, 480.0, accuracy: 0.001)
        XCTAssertEqual(cuesV[1].y, 1080.0 * 0.75, accuracy: 0.001) // Visual bottom
    }

    func testKeyCuesFadeOutWhenRegionTooSmall() {
        let tinyRegion = CGRect(x: 0, y: 0, width: 30, height: 30)
        let cues = layout.keyCues(localRegion: tinyRegion, screenFrame: screen)
        XCTAssertTrue(cues.isEmpty, "Cues should not clutter when region is smaller than threshold")
    }

    func testProspectiveTargetPoints() {
        let ptsH = layout.prospectiveTargetPoints(for: screen, screenFrame: screen)
        XCTAssertEqual(ptsH.count, 2)
        XCTAssertEqual(ptsH[0], CGPoint(x: 480, y: 540))
        XCTAssertEqual(ptsH[1], CGPoint(x: 1440, y: 540))

        let leftHalf = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let ptsV = layout.prospectiveTargetPoints(for: leftHalf, screenFrame: screen)
        XCTAssertEqual(ptsV.count, 2)
        XCTAssertEqual(ptsV[0], CGPoint(x: 480, y: 810)) // Top center
        XCTAssertEqual(ptsV[1], CGPoint(x: 480, y: 270)) // Bottom center
    }

    // MARK: - KeyMap Integration & Undo Binding

    func testKeyMapAssignsJAndKToNavigationAndHToUndo() {
        let keyMap = KeyMap(layout: layout)

        // J & K are navigation
        XCTAssertEqual(keyMap.label(for: .defaultNav, key: .j), "Left / Top")
        XCTAssertEqual(keyMap.label(for: .defaultNav, key: .k), "Right / Bottom")

        // H remains Undo in default navigation layer
        XCTAssertEqual(keyMap.label(for: .defaultNav, key: .h), "Undo")
    }

    func testOtherLayersRemainUnchanged() {
        let keyMap = KeyMap(layout: layout)
        let defaultMap = KeyMap.default

        // Action layer
        for key in KeyCode.allCases {
            XCTAssertEqual(keyMap.label(for: .action, key: key), defaultMap.label(for: .action, key: key),
                           "Action layer binding for \(key) should match standard")
        }

        // Scroll layer
        for key in KeyCode.allCases {
            XCTAssertEqual(keyMap.label(for: .scroll, key: key), defaultMap.label(for: .scroll, key: key),
                           "Scroll layer binding for \(key) should match standard")
        }

        // Nudge layer
        for key in KeyCode.allCases {
            XCTAssertEqual(keyMap.label(for: .nudge, key: key), defaultMap.label(for: .nudge, key: key),
                           "Nudge layer binding for \(key) should match standard")
        }

        // Management layer
        for key in KeyCode.allCases {
            XCTAssertEqual(keyMap.label(for: .management, key: key), defaultMap.label(for: .management, key: key),
                           "Management layer binding for \(key) should match standard")
        }
    }

    // MARK: - NavigationEngine Integration

    func testNavigationEngineWithBinaryBifurcationLayout() {
        let screenProvider = MockScreenProvider(screenFrame: screen, mouseLocation: CGPoint(x: 960, y: 540))
        let registry = LayoutRegistry()
        registry.selectLayout(byId: "binary_bifurcation")

        let engine = NavigationEngine(screenProvider: screenProvider, layoutRegistry: registry)
        engine.start()

        XCTAssertEqual(engine.currentRegion, screen)

        // Step 1: Press H (choose Left tile)
        engine.navigate(tileId: "first")
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 960, height: 1080))

        // Step 2: Press J (choose Bottom tile in vertical orientation)
        engine.navigate(tileId: "second")
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 960, height: 540))

        // Step 3: Press H (choose Left tile in horizontal orientation)
        engine.navigate(tileId: "first")
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 480, height: 540))

        // Undo step 3
        XCTAssertTrue(engine.undo())
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 960, height: 540))

        // Undo step 2
        XCTAssertTrue(engine.undo())
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 960, height: 1080))

        // Redo step 2
        engine.redo()
        XCTAssertEqual(engine.currentRegion, CGRect(x: 0, y: 0, width: 960, height: 540))
    }
}
