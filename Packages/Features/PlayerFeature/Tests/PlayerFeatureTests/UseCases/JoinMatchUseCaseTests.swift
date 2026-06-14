import XCTest
@testable import PlayerFeature

final class JoinMatchUseCaseTests: XCTestCase {

    func test_execute_forwardsIdAndTeam_andReturnsJoinData() async throws {
        let service = MockMatchService()
        let expected = JoinMatchData.stub(paymentId: "pay-99")
        service.joinMatchResult = .success(expected)
        let sut = JoinMatchUseCase(matchService: service)

        let result = try await sut.execute(matchId: "m-1", team: "A")

        XCTAssertEqual(service.joinMatchCallCount, 1)
        XCTAssertEqual(service.lastJoinId, "m-1")
        XCTAssertEqual(service.lastJoinTeam, "A")
        XCTAssertEqual(result, expected)
    }

    func test_execute_forwardsNilTeam() async throws {
        let service = MockMatchService()
        let sut = JoinMatchUseCase(matchService: service)

        _ = try await sut.execute(matchId: "m-1", team: nil)

        XCTAssertNil(service.lastJoinTeam)
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        service.joinMatchResult = .failure(TestError.boom)
        let sut = JoinMatchUseCase(matchService: service)

        do {
            _ = try await sut.execute(matchId: "m-1", team: "A")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
