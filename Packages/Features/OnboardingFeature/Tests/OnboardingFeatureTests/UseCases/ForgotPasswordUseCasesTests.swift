import XCTest
@testable import OnboardingFeature

// MARK: - ForgotPasswordUseCase

final class ForgotPasswordUseCaseTests: XCTestCase {

    func test_execute_forwardsEmail_andReturnsResponse() async throws {
        let auth = MockAuthService()
        auth.forgotPasswordResult = .success(.stub(userId: "u-1", resendCodeTimeInSeconds: 30))
        let sut = ForgotPasswordUseCase(authService: auth)

        let result = try await sut.execute(email: "a@b.com")

        XCTAssertEqual(auth.lastForgotEmail, "a@b.com")
        XCTAssertEqual(result.data.userId, "u-1")
        XCTAssertEqual(result.data.resendCodeTimeInSeconds, 30)
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.forgotPasswordResult = .failure(TestError.boom)
        let sut = ForgotPasswordUseCase(authService: auth)

        do {
            _ = try await sut.execute(email: "a@b.com")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - VerifyResetMFAUseCase

final class VerifyResetMFAUseCaseTests: XCTestCase {

    func test_execute_forwardsArgs_andReturnsResetToken() async throws {
        let auth = MockAuthService()
        auth.verifyResetMFAResult = .success(.stub(resetToken: "tok-123"))
        let sut = VerifyResetMFAUseCase(authService: auth)

        let result = try await sut.execute(userId: "u-1", code: "654321")

        XCTAssertEqual(auth.lastVerifyResetUserId, "u-1")
        XCTAssertEqual(auth.lastVerifyResetCode, "654321")
        XCTAssertEqual(result.data.resetToken, "tok-123")
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.verifyResetMFAResult = .failure(TestError.boom)
        let sut = VerifyResetMFAUseCase(authService: auth)

        do {
            _ = try await sut.execute(userId: "u-1", code: "0")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - ResetPasswordUseCase

final class ResetPasswordUseCaseTests: XCTestCase {

    func test_execute_forwardsArgs_andReturnsResponse() async throws {
        let auth = MockAuthService()
        auth.resetPasswordResult = .success(.stub(success: true, message: "Listo"))
        let sut = ResetPasswordUseCase(authService: auth)

        let result = try await sut.execute(newPassword: "NewPass1!", resetToken: "tok-123")

        XCTAssertEqual(auth.lastResetNewPassword, "NewPass1!")
        XCTAssertEqual(auth.lastResetToken, "tok-123")
        XCTAssertTrue(result.data.success)
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.resetPasswordResult = .failure(TestError.boom)
        let sut = ResetPasswordUseCase(authService: auth)

        do {
            _ = try await sut.execute(newPassword: "x", resetToken: "y")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
