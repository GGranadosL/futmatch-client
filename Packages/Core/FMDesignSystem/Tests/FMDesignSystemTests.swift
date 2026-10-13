import XCTest
import SwiftUI
@testable import FMDesignSystem

final class FMDesignSystemTests: XCTestCase {
    func testColorsExist() {
        XCTAssertNotNil(FMColors.primary)
        XCTAssertNotNil(FMColors.secondary)
    }
}

final class FMColorHexParsingTests: XCTestCase {
    func test_fmHex_parsesSixDigitHex_withOrWithoutHash() {
        XCTAssertNotNil(Color(fmHex: "#315DA8"))
        XCTAssertNotNil(Color(fmHex: "315DA8"))
    }

    func test_fmHex_rejectsUnparseableValues() {
        XCTAssertNil(Color(fmHex: ""))
        XCTAssertNil(Color(fmHex: "#12"))
        XCTAssertNil(Color(fmHex: "#GGGGGG"))
        XCTAssertNil(Color(fmHex: "blue"))
    }
}
