import XCTest
@testable import PlayerFeature

final class FetchMatchDetailUseCaseTests: XCTestCase {

    func test_execute_forwardsId_andReturnsMatch() async throws {
        let service = MockMatchService()
        let expected = MatchItem.stub(id: "m-42", venueName: "El Coloso")
        service.fetchMatchDetailResult = .success(expected)
        let sut = FetchMatchDetailUseCase(matchService: service)

        let result = try await sut.execute(matchId: "m-42")

        XCTAssertEqual(service.fetchMatchDetailCallCount, 1)
        XCTAssertEqual(service.lastDetailId, "m-42")
        XCTAssertEqual(result, expected)
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        service.fetchMatchDetailResult = .failure(TestError.boom)
        let sut = FetchMatchDetailUseCase(matchService: service)

        do {
            _ = try await sut.execute(matchId: "m-42")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
