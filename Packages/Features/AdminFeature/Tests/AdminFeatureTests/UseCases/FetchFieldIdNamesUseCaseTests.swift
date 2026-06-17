import XCTest
@testable import AdminFeature

final class FetchFieldIdNamesUseCaseTests: XCTestCase {

    func test_execute_returnsRepositoryResult() async throws {
        let repo = MockFieldRepository()
        let expected = [FieldIdName.stub(id: "a", name: "Cancha A"),
                        FieldIdName.stub(id: "b", name: "Cancha B")]
        repo.fetchFieldIdNamesResult = .success(expected)
        let sut = FetchFieldIdNamesUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertEqual(repo.fetchFieldIdNamesCallCount, 1)
        XCTAssertEqual(result, expected)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.fetchFieldIdNamesResult = .failure(TestError.boom)
        let sut = FetchFieldIdNamesUseCase(repository: repo)

        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
