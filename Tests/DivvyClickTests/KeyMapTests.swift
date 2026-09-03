import CoreGraphics
import DivvyClickCoordination
import DivvyClickCore
import DivvyClickEngine
import DivvyClickLayouts
import XCTest

@MainActor
final class KeyMapTests: XCTestCase {

    // MARK: - Default Navigation Layer

    func testDefaultNavLabelsForGridKeys() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.i, "↑"), (.k, "↓"),
            (.j, "←"), (.l, "→")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.default.label(for: .defaultNav, key: key),
                expectedLabel,
                "Default nav label for \(key.string) should be \(expectedLabel)"
            )
        }

        let unboundKeys: [KeyCode] = [.u, .o, .m, .comma, .period]
        for key in unboundKeys {
            XCTAssertNil(
                KeyMap.default.label(for: .defaultNav, key: key),
                "Default nav layer should not have binding for \(key.string)"
            )
        }
    }

    func testGrid3x3KeyMapLabels() {
        let keyMap3x3 = KeyMap(layout: Grid3x3Layout())
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.u, "↖"), (.i, "↑"), (.o, "↗"),
            (.j, "←"), (.k, "○"), (.l, "→"),
            (.m, "↙"), (.comma, "↓"), (.period, "↘")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                keyMap3x3.label(for: .defaultNav, key: key),
                expectedLabel,
                "3x3 nav label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    // MARK: - Action Layer

    func testActionLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.j, "Double"), (.k, "Middle"), (.l, "Left Click"),
            (.m, "Start Drag"), (.comma, "Drop")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.default.label(for: .action, key: key),
                expectedLabel,
                "Action layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    func testActionLayerUnboundKeysReturnNil() {
        // Unbound keys in action layer
        let unboundKeys: [KeyCode] = [.u, .i, .o]
        for key in unboundKeys {
            XCTAssertNil(
                KeyMap.default.label(for: .action, key: key),
                "Action layer should not have binding for \(key.string)"
            )
        }
    }

    // MARK: - Scroll Layer

    func testScrollLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.u, "Scroll Up"), (.i, "Auto Up"), (.k, "Stop"),
            (.m, "Scroll Down"), (.comma, "Auto Down"),
            (.j, "Scroll Left"), (.l, "Scroll Right")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.default.label(for: .scroll, key: key),
                expectedLabel,
                "Scroll layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    // MARK: - Fast Move Layer

    func testFastMoveLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.i, "Fast ↑"), (.k, "Fast ↓"),
            (.j, "Fast ←"), (.l, "Fast →")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.default.label(for: .fastMove, key: key),
                expectedLabel,
                "Fast move layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    // MARK: - Management Layer

    func testManagementLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"), (.j, "Redo"),
            (.k, "Reset"), (.l, "Display")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.default.label(for: .management, key: key),
                expectedLabel,
                "Management layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    // MARK: - Binding Symmetry

    func testEveryBindingHasNonEmptyLabel() {
        let layers: [NavigationEngine.ActiveLayer] = [.defaultNav, .action, .scroll, .fastMove, .management]

        for layer in layers {
            for key in KeyCode.allCases {
                if let label = KeyMap.default.label(for: layer, key: key) {
                    XCTAssertFalse(label.isEmpty, "Label for \(key.string) in \(layer) should not be empty")
                }
            }
        }
    }

    // MARK: - Custom Mappings & Injection

    func testCustomKeyMapInitializationAndLookup() {
        let customKeyMap = KeyMap(mappings: [
            .defaultNav: [
                .space: KeyBinding(label: "Custom Space")
            ]
        ])

        XCTAssertEqual(customKeyMap.label(for: .defaultNav, key: .space), "Custom Space")
        XCTAssertNil(customKeyMap.label(for: .defaultNav, key: .i), "Custom key map should not contain unmapped default keys")
        XCTAssertNil(customKeyMap.label(for: .action, key: .j), "Custom key map should have empty action layer")
    }

    // MARK: - Execution Tests

    func testKeyMapExecution() {
        let screenProvider = MockScreenProvider(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            mouseLocation: CGPoint(x: 960, y: 540)
        )
        let engine = NavigationEngine(screenProvider: screenProvider)
        let coordinator = NavigationCoordinator(engine: engine, cursorEngine: MockCursorEngine())

        var executedCustomAction = false
        let customKeyMap = KeyMap(mappings: [
            .defaultNav: [
                .a: KeyBinding(label: "Custom Action") { _, _ in
                    executedCustomAction = true
                },
                .s: KeyBinding(label: "No Action", action: nil)
            ]
        ])

        // Mapped key with action
        let executed = customKeyMap.execute(for: .defaultNav, key: .a, coordinator: coordinator, flags: [])
        XCTAssertTrue(executed)
        XCTAssertTrue(executedCustomAction)

        // Mapped key without action
        let noActionExecuted = customKeyMap.execute(for: .defaultNav, key: .s, coordinator: coordinator, flags: [])
        XCTAssertFalse(noActionExecuted)

        // Unmapped key
        let unmappedExecuted = customKeyMap.execute(for: .defaultNav, key: .d, coordinator: coordinator, flags: [])
        XCTAssertFalse(unmappedExecuted)
    }
}
