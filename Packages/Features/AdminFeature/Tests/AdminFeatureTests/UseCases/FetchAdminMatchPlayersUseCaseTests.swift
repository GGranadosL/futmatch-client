import XCTest
@testable import AdminFeature

final class FetchAdminMatchPlayersUseCaseTests: XCTestCase {

    func test_execute_delegatesToRepository_withCorrectMatchId() async throws {
        let repo = MockAdminMatchRepository()
        let teamA = [AdminMatchPlayer.stub(id: "p1", name: "Alice")]
        let teamB = [AdminMatchPlayer.stub(id: "p2", name: "Bob")]
        repo.fetchMatchPlayersResult = .success((teamA: teamA, teamB: teamB))
        let sut = FetchAdminMatchPlayersUseCase(repository: repo)

        let result = try await sut.execute(matchId: "m-42")

        XCTAssertEqual(repo.fetchMatchPlayersCallCount, 1)
        XCTAssertEqual(repo.lastFetchMatchPlayersId, "m-42")
        XCTAssertEqual(result.teamA, teamA)
        XCTAssertEqual(result.teamB, teamB)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockAdminMatchRepository()
        repo.fetchMatchPlayersResult = .failure(TestError.boom)
        let sut = FetchAdminMatchPlayersUseCase(repository: repo)

        do {
            _ = try await sut.execute(matchId: "m-1")
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
