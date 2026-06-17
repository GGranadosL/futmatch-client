import XCTest
@testable import OnboardingFeature

final class RegisterUserUseCaseTests: XCTestCase {

    private func makeRequest() -> RegisterStartRequest {
        RegisterStartRequest(
            name: "Ana",
            lastName: "López",
            email: "ana@b.com",
            password: "Strong123!",
            phone: "5512345678",
            country: "México",
            birthDate: 0,
            gender: .male,
            playerPosition: .midfielder,
            profilePic: nil,
            level: .amateur,
            userRole: .player
        )
    }

    func test_execute_mapsResponseToResult() async throws {
        let auth = MockAuthService()
        auth.registerStartResult = .success(.stub(success: true, message: "Revisa tu correo", resendCodeTimeInSeconds: 90))
        let sut = RegisterUserUseCase(authService: auth)

        let result = try await sut.execute(request: makeRequest())

        XCTAssertEqual(auth.lastRegisterStartRequest?.email, "ana@b.com")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Revisa tu correo")
        XCTAssertEqual(result.resendCodeTimeInSeconds, 90)
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.registerStartResult = .failure(TestError.boom)
        let sut = RegisterUserUseCase(authService: auth)

        do {
            _ = try await sut.execute(request: makeRequest())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
