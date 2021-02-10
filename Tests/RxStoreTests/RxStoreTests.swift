import XCTest
@testable import RxStore

final class RxStoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(RxStore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
