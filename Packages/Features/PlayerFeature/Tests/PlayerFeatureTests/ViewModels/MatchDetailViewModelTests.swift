import XCTest
@testable import PlayerFeature

// MARK: - MatchDetailViewModelTests

@MainActor
final class MatchDetailViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        match: MatchItem = .stub(),
        joinUseCase: MockJoinMatchUseCase = MockJoinMatchUseCase(),
        subscribeUseCase: MockSubscribeMatchPlayersUseCase = MockSubscribeMatchPlayersUseCase()
    ) -> MatchDetailViewModel {
        MatchDetailViewModel(
            initialMatch: match,
            fetchDetailUseCase: MockFetchMatchDetailUseCase(),
            joinMatchUseCase: joinUseCase,
            pollPaymentStatusUseCase: MockPollPaymentStatusUseCase(),
            subscribePlayersUseCase: subscribeUseCase,
            cancelMatchUseCase: MockCancelMatchUseCase(),
            leaveMatchUseCase: MockLeaveMatchUseCase()
        )
    }

    // MARK: - subscribeToPlayers: final states bypass Firestore

    func test_subscribeToPlayers_canceledMatch_populatesFromMatchRoster_withoutCallingFirestore() async {
        let player = MatchPlayer(id: "p1", playerId: "p1", name: "Alice", status: .joined)
        let match = MatchItem.stub(
            teamAPlayers: [player],
            matchStatus: "CANCELED"
        )
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(sut.liveTeamAPlayers, [player])
        XCTAssertEqual(sut.liveTeamBPlayers, [])
        XCTAssertEqual(subscribeUseCase.callCount, 0, "Firestore must not be subscribed for a canceled match")
    }

    func test_subscribeToPlayers_completedMatch_populatesFromMatchRoster_withoutCallingFirestore() async {
        let player = MatchPlayer(id: "p2", playerId: "p2", name: "Bob", status: .joined)
        let match = MatchItem.stub(
            teamBPlayers: [player],
            matchStatus: "COMPLETED"
        )
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(sut.liveTeamBPlayers, [player])
        XCTAssertEqual(subscribeUseCase.callCount, 0, "Firestore must not be subscribed for a completed match")
    }

    func test_subscribeToPlayers_cancelledVariant_bypasses_firestore() async {
        // Backend may return "CANCELLED" (double-L)
        let match = MatchItem.stub(matchStatus: "CANCELLED")
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(subscribeUseCase.callCount, 0)
    }

    func test_subscribeToPlayers_scheduledMatch_subscribesToFirestore() async {
        let snapshot = MatchPlayersSnapshot.stub(teamA: [.stub()])
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [snapshot]
        let match = MatchItem.stub(matchStatus: "SCHEDULED")
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(subscribeUseCase.callCount, 1, "Firestore must be subscribed for active matches")
        XCTAssertEqual(sut.liveTeamAPlayers, snapshot.teamAPlayers)
    }

    // MARK: - joinMatch: reused payment

    func test_joinMatch_reusedPayment_setsJoinedAndRaisesReusedFlag() async {
        let reusedData = JoinMatchData.stub(
            clientSecret: nil,
            customer: nil,
            customerSessionClientSecret: nil,
            publishableKey: nil,
            reusedExistingPayment: true,
            existingPaymentStatus: "SUCCEEDED"
        )
        let joinUseCase = MockJoinMatchUseCase()
        joinUseCase.result = .success(reusedData)
        let sut = makeSUT(joinUseCase: joinUseCase)

        await sut.joinMatch(team: "A")

        XCTAssertTrue(sut.isCurrentUserJoined, "User should be marked as joined immediately on payment reuse")
        XCTAssertTrue(sut.paymentWasReused, "paymentWasReused flag must be raised")
        XCTAssertNil(sut.joinData, "joinData must be cleared — no Stripe sheet needed")
        XCTAssertNil(sut.joinError)
    }

    func test_joinMatch_normalPayment_setsJoinData_doesNotRaiseReusedFlag() async {
        let normalData = JoinMatchData.stub(reusedExistingPayment: false)
        let joinUseCase = MockJoinMatchUseCase()
        joinUseCase.result = .success(normalData)
        let sut = makeSUT(joinUseCase: joinUseCase)

        await sut.joinMatch(team: "B")

        XCTAssertFalse(sut.paymentWasReused)
        XCTAssertFalse(sut.isCurrentUserJoined, "isCurrentUserJoined must not be set by normal join — polling does that")
        XCTAssertEqual(sut.joinData, normalData)
    }

    func test_joinMatch_failure_setsError_doesNotRaiseReusedFlag() async {
        let joinUseCase = MockJoinMatchUseCase()
        joinUseCase.result = .failure(TestError.boom)
        let sut = makeSUT(joinUseCase: joinUseCase)

        await sut.joinMatch(team: nil)

        XCTAssertFalse(sut.paymentWasReused)
        XCTAssertFalse(sut.isCurrentUserJoined)
        XCTAssertNotNil(sut.joinError)
    }
}

// MARK: - MatchPlayer stub

private extension MatchPlayer {
    static func stub(
        id: String = "p-1",
        name: String = "Jugador",
        status: PlayerStatus = .joined
    ) -> MatchPlayer {
        MatchPlayer(id: id, playerId: id, name: name, status: status)
    }
}
