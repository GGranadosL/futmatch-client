import XCTest
@testable import AdminFeature

final class UploadFieldImageUseCaseTests: XCTestCase {

    func test_execute_forwardsArgs_andReturnsNewImageId() async throws {
        let repo = MockFieldRepository()
        repo.uploadFieldImageResult = .success("img-123")
        let sut = UploadFieldImageUseCase(repository: repo)
        let data = Data([0x1, 0x2, 0x3])

        let result = try await sut.execute(fieldId: "f-1", position: 2, imageData: data)

        XCTAssertEqual(repo.uploadFieldImageCallCount, 1)
        XCTAssertEqual(repo.lastUploadFieldId, "f-1")
        XCTAssertEqual(repo.lastUploadPosition, 2)
        XCTAssertEqual(repo.lastUploadData, data)
        XCTAssertEqual(result, "img-123")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.uploadFieldImageResult = .failure(TestError.boom)
        let sut = UploadFieldImageUseCase(repository: repo)

        do {
            _ = try await sut.execute(fieldId: "f-1", position: 0, imageData: Data())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
