import XCTest
@testable import AdminFeature

final class ReplaceFieldImageUseCaseTests: XCTestCase {

    func test_execute_forwardsArgs_andReturnsUpdatedImageId() async throws {
        let repo = MockFieldRepository()
        repo.replaceFieldImageResult = .success("img-new")
        let sut = ReplaceFieldImageUseCase(repository: repo)
        let data = Data([0xA, 0xB])

        let result = try await sut.execute(fieldId: "f-1", imageId: "img-old", imageData: data)

        XCTAssertEqual(repo.replaceFieldImageCallCount, 1)
        XCTAssertEqual(repo.lastReplaceFieldId, "f-1")
        XCTAssertEqual(repo.lastReplaceImageId, "img-old")
        XCTAssertEqual(repo.lastReplaceData, data)
        XCTAssertEqual(result, "img-new")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.replaceFieldImageResult = .failure(TestError.boom)
        let sut = ReplaceFieldImageUseCase(repository: repo)

        do {
            _ = try await sut.execute(fieldId: "f-1", imageId: "img-old", imageData: Data())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
