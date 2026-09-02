import XCTest
import CoreGraphics
@testable import Sources_DivvyClick_lib

@MainActor
final class HotkeyManagerTests: XCTestCase {

    private func makeHotkeyManager(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540)
    ) -> (HotkeyManager, NavigationCoordinator, NavigationEngine, MockCursorEngine) {
        let screenProvider = MockScreenProvider(screenFrame: screenFrame, mouseLocation: mouseLocation)
        let engine = NavigationEngine(screenProvider: screenProvider)
        let cursorEngine = MockCursorEngine()
        let coordinator = NavigationCoordinator(engine: engine, cursorEngine: cursorEngine)
        let hotkeyManager = HotkeyManager(coordinator: coordinator)
        return (hotkeyManager, coordinator, engine, cursorEngine)
    }

    private func createKeyEvent(type: CGEventType, keyCode: KeyCode, flags: CGEventFlags = []) -> CGEvent {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode.rawValue), keyDown: type == .keyDown)!
        event.flags = flags
        return event
    }

    private func createFlagsEvent(flags: CGEventFlags) -> CGEvent {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(source: source)!
        event.type = .flagsChanged
        event.flags = flags
        return event
    }

    // MARK: - Double Tap Command Tests

    func testDoubleTapCommandTogglesEngineSynchronously() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()

        XCTAssertFalse(engine.isActive)

        // 1st Command tap (press)
        let cmdDown1 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown1, type: .flagsChanged)
        XCTAssertFalse(engine.isActive, "Single tap should not activate engine")
        XCTAssertNotNil(hotkeyManager.lastCommandTapTime)
        XCTAssertTrue(hotkeyManager.wasCommandPressed)

        // Command release
        let cmdUp1 = createFlagsEvent(flags: [])
        _ = hotkeyManager.handleEvent(cmdUp1, type: .flagsChanged)
        XCTAssertFalse(engine.isActive)
        XCTAssertFalse(hotkeyManager.wasCommandPressed)

        // 2nd Command tap within threshold (press)
        let cmdDown2 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown2, type: .flagsChanged)
        XCTAssertTrue(engine.isActive, "Double tap should synchronously activate engine")
        XCTAssertNil(hotkeyManager.lastCommandTapTime)

        // Double tap again to stop
        let cmdUp2 = createFlagsEvent(flags: [])
        _ = hotkeyManager.handleEvent(cmdUp2, type: .flagsChanged)

        let cmdDown3 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown3, type: .flagsChanged)
        let cmdUp3 = createFlagsEvent(flags: [])
        _ = hotkeyManager.handleEvent(cmdUp3, type: .flagsChanged)

        let cmdDown4 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown4, type: .flagsChanged)
        XCTAssertFalse(engine.isActive, "Second double tap should synchronously deactivate engine")
    }

    func testRegularKeyDownBreaksDoubleTapSequence() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()

        // 1st Command tap
        let cmdDown1 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown1, type: .flagsChanged)
        XCTAssertNotNil(hotkeyManager.lastCommandTapTime)

        let cmdUp1 = createFlagsEvent(flags: [])
        _ = hotkeyManager.handleEvent(cmdUp1, type: .flagsChanged)

        // Regular key down (e.g. 'i')
        let iKeyDown = createKeyEvent(type: .keyDown, keyCode: .i)
        _ = hotkeyManager.handleEvent(iKeyDown, type: .keyDown)
        XCTAssertNil(hotkeyManager.lastCommandTapTime, "Regular key press should reset double-tap timer")

        // 2nd Command tap after regular key should NOT trigger activation
        let cmdDown2 = createFlagsEvent(flags: [.maskCommand])
        _ = hotkeyManager.handleEvent(cmdDown2, type: .flagsChanged)
        XCTAssertFalse(engine.isActive, "Interrupted double tap should not activate engine")
    }

    // MARK: - Event Routing & Swallowing Tests

    func testEventsPassThroughWhenEngineInactive() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        XCTAssertFalse(engine.isActive)

        let event = createKeyEvent(type: .keyDown, keyCode: .i)
        let result = hotkeyManager.handleEvent(event, type: .keyDown)

        XCTAssertNotNil(result, "Events should pass through when engine is inactive")
        XCTAssertNil(engine.currentRegion)
    }

    func testNavigationalKeysSwallowedAndExecutedSynchronouslyWhenActive() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()
        XCTAssertTrue(engine.isActive)

        let initialRegion = engine.currentRegion!

        // Press 'i' (↑ navigation)
        let iKeyDown = createKeyEvent(type: .keyDown, keyCode: .i)
        let result = hotkeyManager.handleEvent(iKeyDown, type: .keyDown)

        XCTAssertNil(result, "Navigational key should be swallowed synchronously")
        XCTAssertNotEqual(engine.currentRegion, initialRegion, "Action should execute synchronously")
        XCTAssertEqual(engine.currentRegion?.maxY, initialRegion.maxY)

        // Press 'h' (Undo)
        let hKeyDown = createKeyEvent(type: .keyDown, keyCode: .h)
        let undoResult = hotkeyManager.handleEvent(hKeyDown, type: .keyDown)

        XCTAssertNil(undoResult, "Undo key should be swallowed synchronously")
        XCTAssertEqual(engine.currentRegion, initialRegion, "Undo should restore initial region synchronously")
    }

    func testNonSwallowedKeyPassesThroughWhenActive() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()
        XCTAssertTrue(engine.isActive)

        // 'y' is not in isSwallowedKey list
        let yKeyDown = createKeyEvent(type: .keyDown, keyCode: .y)
        let result = hotkeyManager.handleEvent(yKeyDown, type: .keyDown)

        XCTAssertNotNil(result, "Non-swallowed key should pass through even when active")
    }

    // MARK: - Layer State Tracking Tests

    func testLayerKeysTrackingSynchronously() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()

        // Press 'd' (Action layer)
        let dKeyDown = createKeyEvent(type: .keyDown, keyCode: .d)
        _ = hotkeyManager.handleEvent(dKeyDown, type: .keyDown)
        XCTAssertTrue(hotkeyManager.isDHeld)
        XCTAssertEqual(engine.layerState.activeLayer, .action)

        // Release 'd'
        let dKeyUp = createKeyEvent(type: .keyUp, keyCode: .d)
        _ = hotkeyManager.handleEvent(dKeyUp, type: .keyUp)
        XCTAssertFalse(hotkeyManager.isDHeld)
        XCTAssertNil(engine.layerState.activeLayer)

        // Press 'f' (Scroll layer)
        let fKeyDown = createKeyEvent(type: .keyDown, keyCode: .f)
        _ = hotkeyManager.handleEvent(fKeyDown, type: .keyDown)
        XCTAssertTrue(hotkeyManager.isFHeld)
        XCTAssertEqual(engine.layerState.activeLayer, .scroll)

        // Release 'f'
        let fKeyUp = createKeyEvent(type: .keyUp, keyCode: .f)
        _ = hotkeyManager.handleEvent(fKeyUp, type: .keyUp)
        XCTAssertFalse(hotkeyManager.isFHeld)
        XCTAssertNil(engine.layerState.activeLayer)

        // Press 's' (Fast Move layer)
        let sKeyDown = createKeyEvent(type: .keyDown, keyCode: .s)
        _ = hotkeyManager.handleEvent(sKeyDown, type: .keyDown)
        XCTAssertTrue(hotkeyManager.isSHeld)
        XCTAssertEqual(engine.layerState.activeLayer, .fastMove)

        // Release 's'
        let sKeyUp = createKeyEvent(type: .keyUp, keyCode: .s)
        _ = hotkeyManager.handleEvent(sKeyUp, type: .keyUp)
        XCTAssertFalse(hotkeyManager.isSHeld)
        XCTAssertNil(engine.layerState.activeLayer)

        // Press 'a' (Management layer)
        let aKeyDown = createKeyEvent(type: .keyDown, keyCode: .a)
        _ = hotkeyManager.handleEvent(aKeyDown, type: .keyDown)
        XCTAssertTrue(hotkeyManager.isAHeld)
        XCTAssertEqual(engine.layerState.activeLayer, .management)

        // Release 'a'
        let aKeyUp = createKeyEvent(type: .keyUp, keyCode: .a)
        _ = hotkeyManager.handleEvent(aKeyUp, type: .keyUp)
        XCTAssertFalse(hotkeyManager.isAHeld)
        XCTAssertNil(engine.layerState.activeLayer)
    }

    func testEngineDeactivationResetsHeldKeys() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()

        let aKeyDown = createKeyEvent(type: .keyDown, keyCode: .a)
        _ = hotkeyManager.handleEvent(aKeyDown, type: .keyDown)
        XCTAssertTrue(hotkeyManager.isAHeld)
        XCTAssertEqual(engine.layerState.activeLayer, .management)

        // Stop engine
        engine.stop()

        XCTAssertFalse(hotkeyManager.isAHeld, "Engine deactivation should reset held keys")
        XCTAssertNil(engine.layerState.activeLayer)
    }
}
