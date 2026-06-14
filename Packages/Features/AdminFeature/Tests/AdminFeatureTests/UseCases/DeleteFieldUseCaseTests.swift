import XCTest
@testable import AdminFeature

final class DeleteFieldUseCaseTests: XCTestCase {

    func test_execute_forwardsFieldId() async throws {
        let repo = MockFieldRepository()
        let sut = DeleteFieldUseCase(repository: repo)

        try await sut.execute(fieldId: "f-3")

        XCTAssertEqual(repo.deleteFieldCallCount, 1)
        XCTAssertEqual(repo.lastDeleteFieldId, "f-3")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.deleteFieldResult = .failure(TestError.boom)
        let sut = DeleteFieldUseCase(repository: repo)

        do {
            try await sut.execute(fieldId: "f-3")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
