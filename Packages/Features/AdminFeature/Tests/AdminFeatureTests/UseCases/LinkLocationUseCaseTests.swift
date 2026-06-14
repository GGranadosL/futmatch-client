import XCTest
@testable import AdminFeature

final class LinkLocationUseCaseTests: XCTestCase {

    func test_execute_forwardsFieldAndLocationIds() async throws {
        let repo = MockFieldRepository()
        let sut = LinkLocationUseCase(repository: repo)

        try await sut.execute(fieldId: "f-1", locationId: "loc-9")

        XCTAssertEqual(repo.linkLocationCallCount, 1)
        XCTAssertEqual(repo.lastLinkFieldId, "f-1")
        XCTAssertEqual(repo.lastLinkLocationId, "loc-9")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockFieldRepository()
        repo.linkLocationResult = .failure(TestError.boom)
        let sut = LinkLocationUseCase(repository: repo)

        do {
            try await sut.execute(fieldId: "f-1", locationId: "loc-9")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
