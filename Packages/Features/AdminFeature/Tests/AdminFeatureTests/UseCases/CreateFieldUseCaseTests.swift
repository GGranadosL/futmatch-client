import XCTest
@testable import AdminFeature

final class CreateFieldUseCaseTests: XCTestCase {

    func test_execute_forwardsParams_andReturnsCreatedField() async throws {
        let repo = MockFieldRepository()
        let expected = Field.stub(id: "new-field", name: "Mi Cancha")
        repo.createFieldResult = .success(expected)
        let sut = CreateFieldUseCase(repository: repo)
        let params = CreateFieldParams.stub(name: "Mi Cancha")

        let result = try await sut.execute(params)

        XCTAssertEqual(repo.createFieldCallCount, 1)
        XCTAssertEqual(repo.lastCreateParams, params)
        XCTAssertEqual(result, expected)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.createFieldResult = .failure(TestError.boom)
        let sut = CreateFieldUseCase(repository: repo)

        do {
            _ = try await sut.execute(.stub())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
