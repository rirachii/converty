import XCTest
@testable import ConvertyCore

final class TrimRangeTests: XCTestCase {
    func testHandlesCannotCrossOrLeaveSource() {
        var range = TrimRange(duration: 10, start: 2, end: 8)
        range.moveStart(to: 20)
        XCTAssertEqual(range.start, 7.99, accuracy: 0.0001)
        range.moveEnd(to: -4)
        XCTAssertEqual(range.end, 8, accuracy: 0.0001)
        range.moveStart(to: -3)
        range.moveEnd(to: 12)
        XCTAssertEqual(range.start, 0)
        XCTAssertEqual(range.end, 10)
    }

    func testShortClipAndInvalidMetadata() {
        let short = TrimRange(duration: 0.005, start: 0, end: 5)
        XCTAssertEqual(short.start, 0)
        XCTAssertEqual(short.end, 0.005)
        let unknown = TrimRange(duration: .infinity, start: .nan, end: .infinity)
        XCTAssertEqual(unknown.duration, 0)
        XCTAssertEqual(unknown.start, 0)
        XCTAssertEqual(unknown.end, 0)
    }

    func testSelectionClampsWhenSwitchingToShorterFile() {
        var range = TrimRange(duration: 3, start: 4, end: 8)
        XCTAssertEqual(range.start, 2.99, accuracy: 0.0001)
        XCTAssertEqual(range.end, 3)
        range.moveStart(to: .nan)
        range.moveEnd(to: .infinity)
        XCTAssertEqual(range.start, 2.99, accuracy: 0.0001)
        XCTAssertEqual(range.end, 3)
    }
}
