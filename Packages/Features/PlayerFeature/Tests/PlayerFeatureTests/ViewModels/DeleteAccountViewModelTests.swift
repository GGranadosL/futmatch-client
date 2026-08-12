import XCTest
import NetworkFramework
@testable import PlayerFeature

@MainActor
final class DeleteAccountViewModelTests: XCTestCase {

    func test_deleteAccount_success_setsSucceeded() async {
        let useCase = MockDeleteAccountUseCase()
        let sut = DeleteAccountViewModel(deleteAccountUseCase: useCase)

        await sut.deleteAccount(password: "s3cr3t")

        XCTAssertTrue(sut.succeeded)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(useCase.lastPassword, "s3cr3t")
    }

    func test_deleteAccount_conflict_surfacesBackendMessage() async {
        let useCase = MockDeleteAccountUseCase()
        useCase.result = .failure(
            APIError.serverError(
                statusCode: 409,
                title: "No se puede eliminar",
                message: "Tienes un partido programado o en curso.",
                errorCode: "ACCOUNT_HAS_ACTIVE_RESERVATION"
            )
        )
        let sut = DeleteAccountViewModel(deleteAccountUseCase: useCase)

        await sut.deleteAccount(password: "s3cr3t")

        XCTAssertFalse(sut.succeeded)
        XCTAssertEqual(sut.errorMessage, "Tienes un partido programado o en curso.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_deleteAccount_genericError_fallsBackToLocalizedMessage() async {
        let useCase = MockDeleteAccountUseCase()
        useCase.result = .failure(TestError.boom)
        let sut = DeleteAccountViewModel(deleteAccountUseCase: useCase)

        await sut.deleteAccount(password: "s3cr3t")

        XCTAssertFalse(sut.succeeded)
        XCTAssertEqual(sut.errorMessage, L10n.DeleteAccount.genericError)
    }

    func test_clearError_resetsErrorMessage() async {
        let useCase = MockDeleteAccountUseCase()
        useCase.result = .failure(TestError.boom)
        let sut = DeleteAccountViewModel(deleteAccountUseCase: useCase)
        await sut.deleteAccount(password: "s3cr3t")
        XCTAssertNotNil(sut.errorMessage)

        sut.clearError()

        XCTAssertNil(sut.errorMessage)
    }
}

// MARK: - MockDeleteAccountUseCase

final class MockDeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var lastPassword: String?

    func execute(password: String) async throws {
        lastPassword = password
        try result.get()
    }
}
