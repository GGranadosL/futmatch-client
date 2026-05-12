import XCTest
@testable import FMDesignSystem

final class FMDesignSystemTests: XCTestCase {
    func testColorsExist() {
        XCTAssertNotNil(FMColors.primary)
        XCTAssertNotNil(FMColors.secondary)
    }
}
