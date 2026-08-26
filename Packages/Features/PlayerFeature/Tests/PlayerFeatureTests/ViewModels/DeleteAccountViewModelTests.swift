import XCTest
import NetworkFramework
@testable import PlayerFeature

@MainActor
final class DeleteAccountViewModelTests: XCTestCase {

    private func makeSUT(
        deleteUseCase: MockDeleteAccountUseCase = MockDeleteAccountUseCase(),
        confirmIdentityUseCase: MockConfirmDeletionIdentityUseCase = MockConfirmDeletionIdentityUseCase()
    ) -> DeleteAccountViewModel {
        DeleteAccountViewModel(
            deleteAccountUseCase: deleteUseCase,
            confirmIdentityUseCase: confirmIdentityUseCase
        )
    }

    private var validPhrase: String { L10n.DeleteAccount.confirmationPhrase }

    // MARK: - Identity gate

    func test_requestDeletion_success_setsIdentityConfirmed() async {
        let identity = MockConfirmDeletionIdentityUseCase()
        let sut = makeSUT(confirmIdentityUseCase: identity)

        await sut.requestDeletion()

        XCTAssertTrue(sut.identityConfirmed)
        XCTAssertNil(sut.biometricErrorMessage)
        XCTAssertFalse(sut.isVerifyingIdentity)
        XCTAssertEqual(identity.callCount, 1)
    }

    func test_requestDeletion_failure_setsBiometricErrorAndDoesNotConfirm() async {
        let identity = MockConfirmDeletionIdentityUseCase()
        identity.result = .failure(BiometricAuthError.failed)
        let sut = makeSUT(confirmIdentityUseCase: identity)

        await sut.requestDeletion()

        XCTAssertFalse(sut.identityConfirmed)
        XCTAssertEqual(sut.biometricErrorMessage, L10n.DeleteAccount.biometricFailedError)
        XCTAssertFalse(sut.isVerifyingIdentity)
    }

    func test_resetIdentityConfirmation_clearsFlag() async {
        let sut = makeSUT()
        await sut.requestDeletion()
        XCTAssertTrue(sut.identityConfirmed)

        sut.resetIdentityConfirmation()

        XCTAssertFalse(sut.identityConfirmed)
    }

    // MARK: - Local phrase validation

    func test_isConfirmationValid_matchesIgnoringCaseAndWhitespace() {
        let sut = makeSUT()

        XCTAssertTrue(sut.isConfirmationValid(validPhrase))
        XCTAssertTrue(sut.isConfirmationValid("  \(validPhrase.uppercased())  "))
        XCTAssertFalse(sut.isConfirmationValid("something else"))
        XCTAssertFalse(sut.isConfirmationValid(""))
    }

    func test_deleteAccount_withMismatchedPhrase_setsErrorAndDoesNotCallUseCase() async {
        let useCase = MockDeleteAccountUseCase()
        let sut = makeSUT(deleteUseCase: useCase)

        await sut.deleteAccount(confirmation: "nope")

        XCTAssertEqual(sut.errorMessage, L10n.DeleteAccount.phraseMismatchError)
        XCTAssertEqual(useCase.executeCallCount, 0)
        XCTAssertFalse(sut.succeeded)
    }

    // MARK: - Deletion

    func test_deleteAccount_withValidPhrase_success_setsSucceeded() async {
        let useCase = MockDeleteAccountUseCase()
        let sut = makeSUT(deleteUseCase: useCase)

        await sut.deleteAccount(confirmation: "  \(validPhrase.lowercased())  ")

        XCTAssertTrue(sut.succeeded)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(useCase.executeCallCount, 1)
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
        let sut = makeSUT(deleteUseCase: useCase)

        await sut.deleteAccount(confirmation: validPhrase)

        XCTAssertFalse(sut.succeeded)
        XCTAssertEqual(sut.errorMessage, "Tienes un partido programado o en curso.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_deleteAccount_genericError_fallsBackToLocalizedMessage() async {
        let useCase = MockDeleteAccountUseCase()
        useCase.result = .failure(TestError.boom)
        let sut = makeSUT(deleteUseCase: useCase)

        await sut.deleteAccount(confirmation: validPhrase)

        XCTAssertFalse(sut.succeeded)
        XCTAssertEqual(sut.errorMessage, L10n.DeleteAccount.genericError)
    }

    func test_clearError_resetsErrorMessage() async {
        let useCase = MockDeleteAccountUseCase()
        useCase.result = .failure(TestError.boom)
        let sut = makeSUT(deleteUseCase: useCase)
        await sut.deleteAccount(confirmation: validPhrase)
        XCTAssertNotNil(sut.errorMessage)

        sut.clearError()

        XCTAssertNil(sut.errorMessage)
    }
}

// MARK: - Mocks

final class MockDeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var executeCallCount = 0

    func execute() async throws {
        executeCallCount += 1
        try result.get()
    }
}

final class MockConfirmDeletionIdentityUseCase: ConfirmDeletionIdentityUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0

    func execute(reason: String) async throws {
        callCount += 1
        try result.get()
    }
}
