import XCTest
@testable import OnboardingFeature

final class OnboardingFeatureTests: XCTestCase {
    func testRegisterStartRequestCreation() {
        let birthDate = Date(timeIntervalSince1970: 915148800) // timestamp from example
        let birthDateMillis = Int64(birthDate.timeIntervalSince1970 * 1000)
        
        let request = RegisterStartRequest(
            name: "Diego",
            lastName: "Beltran",
            email: "diego.beltran@example.com",
            password: "StrongPassdd123!",
            phone: "5292422233",
            country: "México",
            birthDate: birthDateMillis,
            gender: .male,
            playerPosition: .midfielder,
            profilePic: "https://example.com/images/diego.jpg",
            level: .amateur,
            userRole: .player
        )
        
        XCTAssertEqual(request.email, "diego.beltran@example.com")
        XCTAssertEqual(request.name, "Diego")
        XCTAssertEqual(request.gender, .male)
        XCTAssertEqual(request.playerPosition, .midfielder)
        XCTAssertEqual(request.level, .amateur)
        XCTAssertEqual(request.userRole, .player)
    }
    
    func testAuthTokenExpiration() {
        let expiredToken = AuthToken(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        XCTAssertTrue(expiredToken.isExpired)
        
        let validToken = AuthToken(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        XCTAssertFalse(validToken.isExpired)
    }
}
