import XCTest
@testable import AdminFeature

final class DeleteFieldImageUseCaseTests: XCTestCase {

    func test_execute_forwardsFieldAndImageIds() async throws {
        let repo = MockFieldRepository()
        let sut = DeleteFieldImageUseCase(repository: repo)

        try await sut.execute(fieldId: "f-1", imageId: "img-5")

        XCTAssertEqual(repo.deleteFieldImageCallCount, 1)
        XCTAssertEqual(repo.lastDeleteImageFieldId, "f-1")
        XCTAssertEqual(repo.lastDeleteImageId, "img-5")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.deleteFieldImageResult = .failure(TestError.boom)
        let sut = DeleteFieldImageUseCase(repository: repo)

        do {
            try await sut.execute(fieldId: "f-1", imageId: "img-5")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
