import XCTest
@testable import AdminFeature

@MainActor
final class AdminMatchDetailViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        match: AdminMatch = .stub(),
        fetchPlayersUseCase: MockFetchAdminMatchPlayersUseCase = MockFetchAdminMatchPlayersUseCase(),
        subscribeUseCase: MockSubscribeAdminMatchPlayersUseCase = MockSubscribeAdminMatchPlayersUseCase(),
        cancelUseCase: MockCancelAdminMatchUseCase = MockCancelAdminMatchUseCase()
    ) -> AdminMatchDetailViewModel {
        AdminMatchDetailViewModel(
            match: match,
            fetchFieldsUseCase: MockFetchAdminFieldsUseCase(),
            subscribeUseCase: subscribeUseCase,
            cancelUseCase: cancelUseCase,
            fetchPlayersUseCase: fetchPlayersUseCase,
            rebalanceUseCase: MockRebalanceTeamsUseCase()
        )
    }

    // MARK: - subscribeToPlayers: final states bypass Firestore

    func test_subscribeToPlayers_canceledMatch_callsAPIAndPopulatesTeams() async throws {
        let teamA = [AdminMatchPlayer.stub(id: "p1")]
        let fetchPlayersUseCase = MockFetchAdminMatchPlayersUseCase()
        fetchPlayersUseCase.result = .success((teamA: teamA, teamB: []))
        let subscribeUseCase = MockSubscribeAdminMatchPlayersUseCase()
        let sut = makeSUT(
            match: .stub(status: .canceled),
            fetchPlayersUseCase: fetchPlayersUseCase,
            subscribeUseCase: subscribeUseCase
        )

        await sut.subscribeToPlayers()

        XCTAssertEqual(fetchPlayersUseCase.callCount, 1)
        XCTAssertEqual(subscribeUseCase.callCount, 0, "Firestore must not be subscribed for a canceled match")
        XCTAssertEqual(sut.liveTeamAPlayers, teamA)
        XCTAssertEqual(sut.liveTeamBPlayers, [])
    }

    func test_subscribeToPlayers_completedMatch_callsAPIAndPopulatesTeams() async {
        let teamB = [AdminMatchPlayer.stub(id: "p2")]
        let fetchPlayersUseCase = MockFetchAdminMatchPlayersUseCase()
        fetchPlayersUseCase.result = .success((teamA: [], teamB: teamB))
        let subscribeUseCase = MockSubscribeAdminMatchPlayersUseCase()
        let sut = makeSUT(
            match: .stub(status: .completed),
            fetchPlayersUseCase: fetchPlayersUseCase,
            subscribeUseCase: subscribeUseCase
        )

        await sut.subscribeToPlayers()

        XCTAssertEqual(fetchPlayersUseCase.callCount, 1)
        XCTAssertEqual(subscribeUseCase.callCount, 0, "Firestore must not be subscribed for a completed match")
        XCTAssertEqual(sut.liveTeamBPlayers, teamB)
    }

    func test_subscribeToPlayers_scheduledMatch_subscribesToFirestore() async {
        let snapshot = AdminMatchPlayersSnapshot(teamAPlayers: [.stub()], teamBPlayers: [], reservationsByPlayerId: [:])
        let subscribeUseCase = MockSubscribeAdminMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [snapshot]
        let fetchPlayersUseCase = MockFetchAdminMatchPlayersUseCase()
        let sut = makeSUT(
            match: .stub(status: .scheduled),
            fetchPlayersUseCase: fetchPlayersUseCase,
            subscribeUseCase: subscribeUseCase
        )

        await sut.subscribeToPlayers()

        XCTAssertEqual(subscribeUseCase.callCount, 1, "Firestore must be used for scheduled matches")
        XCTAssertEqual(fetchPlayersUseCase.callCount, 0)
        XCTAssertEqual(sut.liveTeamAPlayers, snapshot.teamAPlayers)
    }

    func test_subscribeToPlayers_finalState_setsPlayersError_whenFetchFails() async {
        let fetchPlayersUseCase = MockFetchAdminMatchPlayersUseCase()
        fetchPlayersUseCase.result = .failure(TestError.boom)
        let sut = makeSUT(
            match: .stub(status: .canceled),
            fetchPlayersUseCase: fetchPlayersUseCase
        )

        await sut.subscribeToPlayers()

        XCTAssertNotNil(sut.playersError)
        XCTAssertNil(sut.liveTeamAPlayers)
    }

    // MARK: - cancelMatch

    func test_cancelMatch_forwardsMatchIdAndReason_andSetsSucceeded() async {
        let cancelUseCase = MockCancelAdminMatchUseCase()
        let sut = makeSUT(match: .stub(id: "match-9"), cancelUseCase: cancelUseCase)

        await sut.cancelMatch(reason: "Razones climáticas.")

        XCTAssertEqual(cancelUseCase.callCount, 1)
        XCTAssertEqual(cancelUseCase.lastMatchId, "match-9")
        XCTAssertEqual(cancelUseCase.lastReason, "Razones climáticas.")
        XCTAssertTrue(sut.cancelSucceeded)
        XCTAssertNil(sut.cancelError)
        XCTAssertFalse(sut.isCanceling)
    }

    func test_cancelMatch_setsCancelError_whenUseCaseThrows() async {
        let cancelUseCase = MockCancelAdminMatchUseCase()
        cancelUseCase.result = .failure(TestError.boom)
        let sut = makeSUT(cancelUseCase: cancelUseCase)

        await sut.cancelMatch(reason: "Otro motivo")

        XCTAssertNotNil(sut.cancelError)
        XCTAssertFalse(sut.cancelSucceeded)
        XCTAssertFalse(sut.isCanceling)
    }
}
