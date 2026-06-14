import XCTest
@testable import PlayerFeature

final class FetchMyMatchesUseCaseTests: XCTestCase {

    func test_execute_forwardsCoordinates_andReturnsMatches() async throws {
        let service = MockMatchService()
        let expected = [MatchItem.stub(id: "mine-1")]
        service.fetchMyMatchesResult = .success(expected)
        let sut = FetchMyMatchesUseCase(matchService: service)

        let result = try await sut.execute(lat: 1.0, lon: 2.0)

        XCTAssertEqual(service.fetchMyMatchesCallCount, 1)
        XCTAssertEqual(service.lastMyMatchesLat, 1.0)
        XCTAssertEqual(service.lastMyMatchesLon, 2.0)
        XCTAssertEqual(result, expected)
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        service.fetchMyMatchesResult = .failure(TestError.boom)
        let sut = FetchMyMatchesUseCase(matchService: service)

        do {
            _ = try await sut.execute(lat: nil, lon: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
