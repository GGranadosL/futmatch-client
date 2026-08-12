import XCTest
@testable import PlayerFeature

final class DeleteAccountUseCaseTests: XCTestCase {

    func test_execute_forwardsPassword() async throws {
        let repository = MockAccountRepository()
        let sut = DeleteAccountUseCase(repository: repository)

        try await sut.execute(password: "s3cr3t")

        XCTAssertEqual(repository.deleteAccountCallCount, 1)
        XCTAssertEqual(repository.lastPassword, "s3cr3t")
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockAccountRepository()
        repository.deleteAccountResult = .failure(TestError.boom)
        let sut = DeleteAccountUseCase(repository: repository)

        do {
            try await sut.execute(password: "s3cr3t")
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
    private(set) var lastPassword: String?

    func deleteAccount(password: String) async throws {
        deleteAccountCallCount += 1
        lastPassword = password
        try deleteAccountResult.get()
    }
}
