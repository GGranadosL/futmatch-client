import XCTest
@testable import PlayerFeature

final class DeleteAccountUseCaseTests: XCTestCase {

    func test_execute_callsRepository() async throws {
        let repository = MockAccountRepository()
        let sut = DeleteAccountUseCase(repository: repository)

        try await sut.execute()

        XCTAssertEqual(repository.deleteAccountCallCount, 1)
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockAccountRepository()
        repository.deleteAccountResult = .failure(TestError.boom)
        let sut = DeleteAccountUseCase(repository: repository)

        do {
            try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - MockAccountRepository

final class MockAccountRepository: AccountRepositoryProtocol {
    var deleteAccountResult: Result<Void, Error> = .success(())
    private(set) var deleteAccountCallCount = 0

    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        try deleteAccountResult.get()
    }
}
