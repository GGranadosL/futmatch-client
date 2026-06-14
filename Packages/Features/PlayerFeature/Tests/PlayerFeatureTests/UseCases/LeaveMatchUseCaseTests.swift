import XCTest
@testable import PlayerFeature

final class LeaveMatchUseCaseTests: XCTestCase {

    func test_execute_forwardsId() async throws {
        let service = MockMatchService()
        let sut = LeaveMatchUseCase(matchService: service)

        try await sut.execute(matchId: "m-7")

        XCTAssertEqual(service.leaveMatchCallCount, 1)
        XCTAssertEqual(service.lastLeaveId, "m-7")
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        service.leaveMatchResult = .failure(TestError.boom)
        let sut = LeaveMatchUseCase(matchService: service)

        do {
            try await sut.execute(matchId: "m-7")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
