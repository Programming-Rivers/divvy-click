import XCTest
@testable import Sources_DivvyClick_lib

@MainActor
final class KeyMapTests: XCTestCase {

    // MARK: - Default Navigation Layer

    func testDefaultNavLabelsForGridKeys() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.u, "↖"), (.i, "↑"), (.o, "↗"),
            (.j, "←"), (.k, "○"), (.l, "→"),
            (.m, "↙"), (.comma, "↓"), (.period, "↘")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.shared.label(for: .defaultNav, key: key),
                expectedLabel,
                "Default nav label for \(key.string) should be \(expectedLabel)"
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
                KeyMap.shared.label(for: .action, key: key),
                expectedLabel,
                "Action layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    func testActionLayerUnboundKeysReturnNil() {
        // Top row navigation keys should not have bindings in action layer
        let unboundKeys: [KeyCode] = [.u, .i, .o]
        for key in unboundKeys {
            XCTAssertNil(
                KeyMap.shared.label(for: .action, key: key),
                "Action layer should not have binding for \(key.string)"
            )
        }
    }

    // MARK: - Scroll Layer

    func testScrollLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.i, "Scroll Up"), (.comma, "Scroll Down"),
            (.j, "Scroll Left"), (.l, "Scroll Right")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.shared.label(for: .scroll, key: key),
                expectedLabel,
                "Scroll layer label for \(key.string) should be \(expectedLabel)"
            )
        }
    }

    // MARK: - Fast Move Layer

    func testFastMoveLayerLabels() {
        let expected: [(KeyCode, String)] = [
            (.h, "Undo"),
            (.u, "Fast ↖"), (.i, "Fast ↑"), (.o, "Fast ↗"),
            (.j, "Fast ←"), (.k, "Fast ○"), (.l, "Fast →"),
            (.m, "Fast ↙"), (.comma, "Fast ↓"), (.period, "Fast ↘")
        ]

        for (key, expectedLabel) in expected {
            XCTAssertEqual(
                KeyMap.shared.label(for: .fastMove, key: key),
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
                KeyMap.shared.label(for: .management, key: key),
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
                if let label = KeyMap.shared.label(for: layer, key: key) {
                    XCTAssertFalse(label.isEmpty, "Label for \(key.string) in \(layer) should not be empty")
                }
            }
        }
    }
}
