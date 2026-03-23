import XCTest
@testable import Sources_DivvyClick_lib

@MainActor
final class KeyMapTests: XCTestCase {

    // MARK: - Default Navigation Layer

    func testDefaultNavLabelsForGridKeys() {
        let expected: [(KeyCode, String)] = [
            (.y, "↖"), (.u, "↑"), (.i, "↗"),
            (.h, "←"), (.j, "○"), (.k, "→"),
            (.n, "↙"), (.m, "↓"), (.comma, "↘"),
            (.l, "Undo")
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
            (.h, "Double"), (.j, "Left Click"), (.k, "Middle"),
            (.l, "Right Click"), (.n, "Start Drag"), (.m, "Drop")
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
        // Grid navigation keys should not have bindings in action layer
        let unboundKeys: [KeyCode] = [.y, .u, .i]
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
            (.u, "Scroll Up"), (.m, "Scroll Down"),
            (.h, "Scroll Left"), (.k, "Scroll Right")
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
            (.y, "Fast ↖"), (.u, "Fast ↑"), (.i, "Fast ↗"),
            (.h, "Fast ←"), (.j, "Fast ○"), (.k, "Fast →"),
            (.n, "Fast ↙"), (.m, "Fast ↓"), (.comma, "Fast ↘"),
            (.l, "Undo")
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
