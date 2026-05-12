import XCTest
@testable import HomeFeature

final class HomeFeatureTests: XCTestCase {
    func testTabsExist() throws {
        XCTAssertEqual(HomeTab.allCases.count, 3)
    }
}
