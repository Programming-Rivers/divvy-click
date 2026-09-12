import CoreGraphics
import DivvyClickCoordination
import DivvyClickCore
import DivvyClickEngine
import DivvyClickUI
import XCTest

@MainActor
final class HotkeyManagerTests: XCTestCase {

    private func makeHotkeyManager(
        screenFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        mouseLocation: CGPoint = CGPoint(x: 960, y: 540),
        keyMap: KeyMap = .default
    ) -> (HotkeyManager, NavigationCoordinator, NavigationEngine, MockCursorEngine) {
        let screenProvider = MockScreenProvider(screenFrame: screenFrame, mouseLocation: mouseLocation)
        let engine = NavigationEngine(screenProvider: screenProvider)
        let cursorEngine = MockCursorEngine()
        let coordinator = NavigationCoordinator(engine: engine, cursorEngine: cursorEngine)
        let hotkeyManager = HotkeyManager(coordinator: coordinator, keyMap: keyMap)
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

    // MARK: - Custom KeyMap Dependency Injection Tests

    func testCustomKeyMapExecutionInHotkeyManager() {
        var customActionInvoked = false
        let customKeyMap = KeyMap(mappings: [
            .defaultNav: [
                .h: KeyBinding(label: "Custom Handler") { _, _ in
                    customActionInvoked = true
                }
            ]
        ])

        let (hotkeyManager, _, engine, _) = makeHotkeyManager(keyMap: customKeyMap)
        engine.start()
        XCTAssertTrue(engine.isActive)

        let hKeyDown = createKeyEvent(type: .keyDown, keyCode: .h)
        let result = hotkeyManager.handleEvent(hKeyDown, type: .keyDown)

        XCTAssertNil(result, "Event should be swallowed by custom key binding")
        XCTAssertTrue(customActionInvoked, "Custom key binding action should be executed")
    }

    // MARK: - Arrow Keys & Nudge Layer Tests

    func testArrowKeysAreSwallowedWhenActive() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()

        let arrowKeys: [KeyCode] = [.upArrow, .downArrow, .leftArrow, .rightArrow]
        for key in arrowKeys {
            XCTAssertTrue(hotkeyManager.isSwallowedKey(key), "Arrow key \(key) should be swallowed")

            let downEvent = createKeyEvent(type: .keyDown, keyCode: key)
            let result = hotkeyManager.handleEvent(downEvent, type: .keyDown)
            XCTAssertNil(result, "KeyDown for \(key) should be swallowed when engine is active")
        }
    }

    func testNudgeLayerKeyUpAndReleaseHandling() {
        let (hotkeyManager, coordinator, engine, _) = makeHotkeyManager()
        engine.start()
        guard let r0 = engine.currentRegion else {
            XCTFail("Region missing")
            return
        }

        // Hold 'S' (Nudge Layer)
        let sKeyDown = createKeyEvent(type: .keyDown, keyCode: .s)
        _ = hotkeyManager.handleEvent(sKeyDown, type: .keyDown)
        XCTAssertEqual(engine.layerState.activeLayer, .nudge)

        // Press 'I' (Nudge Up)
        let iKeyDown = createKeyEvent(type: .keyDown, keyCode: .i)
        _ = hotkeyManager.handleEvent(iKeyDown, type: .keyDown)
        XCTAssertEqual(engine.currentRegion?.midY ?? 0, r0.midY + CGFloat(AppConstants.nudgeBaseStep), accuracy: 0.001)

        // Release 'I'
        let iKeyUp = createKeyEvent(type: .keyUp, keyCode: .i)
        _ = hotkeyManager.handleEvent(iKeyUp, type: .keyUp)

        // Another tap after keyUp should create a second discrete tap and undo point
        _ = hotkeyManager.handleEvent(iKeyDown, type: .keyDown)
        XCTAssertEqual(engine.currentRegion?.midY ?? 0, r0.midY + 2.0 * CGFloat(AppConstants.nudgeBaseStep), accuracy: 0.001)

        // Release 'S' (should stop all nudges)
        let sKeyUp = createKeyEvent(type: .keyUp, keyCode: .s)
        _ = hotkeyManager.handleEvent(sKeyUp, type: .keyUp)
        XCTAssertNil(engine.layerState.activeLayer)

        coordinator.stopAllNudges()
    }

    func testAutoScrollLifecycleThroughKeyEvents() {
        let (hotkeyManager, _, engine, _) = makeHotkeyManager()
        engine.start()

        // 1. Hold 'F' (Scroll Layer)
        let fKeyDown = createKeyEvent(type: .keyDown, keyCode: .f)
        _ = hotkeyManager.handleEvent(fKeyDown, type: .keyDown)
        XCTAssertEqual(engine.layerState.activeLayer, .scroll)

        // 2. Press 'I' (Auto Up)
        let iKeyDown = createKeyEvent(type: .keyDown, keyCode: .i)
        _ = hotkeyManager.handleEvent(iKeyDown, type: .keyDown)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 1)

        // 3. Release 'I' -> Auto-scroll MUST persist and not cancel after one notch
        let iKeyUp = createKeyEvent(type: .keyUp, keyCode: .i)
        _ = hotkeyManager.handleEvent(iKeyUp, type: .keyUp)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 1)

        // 4. Release 'F' -> Leaving the scroll layer MUST persist auto-scroll
        let fKeyUp = createKeyEvent(type: .keyUp, keyCode: .f)
        _ = hotkeyManager.handleEvent(fKeyUp, type: .keyUp)
        XCTAssertNil(engine.layerState.activeLayer)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)

        // 5. Re-enter Scroll Layer with 'F' and press 'K' (Stop)
        _ = hotkeyManager.handleEvent(fKeyDown, type: .keyDown)
        XCTAssertEqual(engine.layerState.activeLayer, .scroll)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .up)

        let kKeyDown = createKeyEvent(type: .keyDown, keyCode: .k)
        _ = hotkeyManager.handleEvent(kKeyDown, type: .keyDown)
        XCTAssertNil(engine.scrollState.autoScrollDirection)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 0)

        // 6. Test Auto Down via ',' and stop via 'K'
        let commaKeyDown = createKeyEvent(type: .keyDown, keyCode: .comma)
        _ = hotkeyManager.handleEvent(commaKeyDown, type: .keyDown)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .down)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 1)

        let commaKeyUp = createKeyEvent(type: .keyUp, keyCode: .comma)
        _ = hotkeyManager.handleEvent(commaKeyUp, type: .keyUp)
        _ = hotkeyManager.handleEvent(fKeyUp, type: .keyUp)
        XCTAssertNil(engine.layerState.activeLayer)
        XCTAssertEqual(engine.scrollState.autoScrollDirection, .down)

        _ = hotkeyManager.handleEvent(fKeyDown, type: .keyDown)
        _ = hotkeyManager.handleEvent(kKeyDown, type: .keyDown)
        XCTAssertNil(engine.scrollState.autoScrollDirection)
        XCTAssertEqual(engine.scrollState.autoScrollSpeed, 0)
    }
}
