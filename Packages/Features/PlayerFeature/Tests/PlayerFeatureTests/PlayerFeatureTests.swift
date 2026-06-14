import XCTest
@testable import PlayerFeature

final class PlayerFeatureTests: XCTestCase {
    func testTabsExist() throws {
        XCTAssertEqual(HomeTab.allCases, [.home, .matches, .reserved, .profile])
    }
}
