import XCTest
@testable import PlayerFeature

final class SubscribeMatchPlayersUseCaseTests: XCTestCase {

    func test_execute_forwardsMatchId_andStreamsRepositorySnapshots() async {
        let listener = MockMatchPlayersListener()
        listener.snapshotsToEmit = [.stub(), .stub()]
        let sut = SubscribeMatchPlayersUseCase(repository: listener)

        let stream = sut.execute(matchId: "m-1")

        var received = 0
        for await _ in stream { received += 1 }

        XCTAssertEqual(listener.lastMatchId, "m-1")
        XCTAssertEqual(received, 2)
    }
}
