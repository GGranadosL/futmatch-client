import XCTest
@testable import PlayerFeature

final class PlayerFeatureTests: XCTestCase {
    func testTabsExist() throws {
        XCTAssertEqual(HomeTab.allCases.count, 3)
    }
}
