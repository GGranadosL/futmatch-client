import XCTest
@testable import AdminFeature

final class UpdateFieldUseCaseTests: XCTestCase {

    func test_execute_forwardsFieldIdAndParams() async throws {
        let repo = MockFieldRepository()
        let sut = UpdateFieldUseCase(repository: repo)
        let params = CreateFieldParams.stub(name: "Editada")

        try await sut.execute(fieldId: "f-7", params)

        XCTAssertEqual(repo.updateFieldCallCount, 1)
        XCTAssertEqual(repo.lastUpdateFieldId, "f-7")
        XCTAssertEqual(repo.lastUpdateParams, params)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.updateFieldResult = .failure(TestError.boom)
        let sut = UpdateFieldUseCase(repository: repo)

        do {
            try await sut.execute(fieldId: "f-7", .stub())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
