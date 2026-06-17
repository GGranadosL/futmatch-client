import XCTest
@testable import AdminFeature

final class FetchAdminFieldsUseCaseTests: XCTestCase {

    func test_execute_returnsRepositoryFields() async throws {
        let repo = MockAdminFieldsRepository()
        let expected = [AdminFieldItem.stub(id: "a"), AdminFieldItem.stub(id: "b")]
        repo.fetchFieldsResult = .success(expected)
        let sut = FetchAdminFieldsUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertEqual(repo.fetchFieldsCallCount, 1)
        XCTAssertEqual(result, expected)
    }

    func test_execute_returnsEmptyWhenRepositoryEmpty() async throws {
        let repo = MockAdminFieldsRepository()
        repo.fetchFieldsResult = .success([])
        let sut = FetchAdminFieldsUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockAdminFieldsRepository()
        repo.fetchFieldsResult = .failure(TestError.boom)
        let sut = FetchAdminFieldsUseCase(repository: repo)

        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
