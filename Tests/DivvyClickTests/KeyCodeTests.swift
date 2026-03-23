import XCTest
@testable import Sources_DivvyClick_lib

final class KeyCodeTests: XCTestCase {

    func testRoundTripConversion() {
        for keyCode in KeyCode.allCases {
            let str = keyCode.string
            let recovered = KeyCode.from(string: str)
            XCTAssertEqual(
                recovered, keyCode,
                "Round-trip failed for \(keyCode): string '\(str)' recovered \(String(describing: recovered))"
            )
        }
    }

    func testUnknownStringReturnsNil() {
        XCTAssertNil(KeyCode.from(string: "Z"))
        XCTAssertNil(KeyCode.from(string: ""))
        XCTAssertNil(KeyCode.from(string: "foo"))
    }

    func testRawValuesAreUnique() {
        var seen = Set<Int64>()
        for keyCode in KeyCode.allCases {
            XCTAssertFalse(
                seen.contains(keyCode.rawValue),
                "Duplicate raw value \(keyCode.rawValue) for \(keyCode)"
            )
            seen.insert(keyCode.rawValue)
        }
    }
}
