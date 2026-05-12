import XCTest
@testable import SharedModels

final class SharedModelsTests: XCTestCase {
    func test_userFullName() {
        let user = User(
            id: "1",
            name: "Gerardo",
            lastName: "Granados",
            email: "test@test.com",
            phone: "+525500000000",
            status: .active,
            country: "México",
            birthDate: Date(),
            gender: .male,
            playerPosition: .goalkeeper,
            profilePic: "",
            level: .intermediate,
            userRole: .organizer,
            isEmailVerified: true
        )
        XCTAssertEqual(user.fullName, "Gerardo Granados")
        XCTAssertEqual(user.countryFlag, "🇲🇽")
    }
}
