import XCTest
@testable import PlayerFeature

final class CancelMatchUseCaseTests: XCTestCase {

    func test_execute_forwardsId() async throws {
        let service = MockMatchService()
        let sut = CancelMatchUseCase(matchService: service)

        try await sut.execute(matchId: "m-1")

        XCTAssertEqual(service.cancelMatchCallCount, 1)
        XCTAssertEqual(service.lastCancelId, "m-1")
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        service.cancelMatchResult = .failure(TestError.boom)
        let sut = CancelMatchUseCase(matchService: service)

        do {
            try await sut.execute(matchId: "m-1")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
