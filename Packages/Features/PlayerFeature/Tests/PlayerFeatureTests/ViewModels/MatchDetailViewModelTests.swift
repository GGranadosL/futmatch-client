import XCTest
import AdminFeature
@testable import PlayerFeature

// MARK: - MatchDetailViewModelTests

@MainActor
final class MatchDetailViewModelTests: XCTestCase {

    static let currentUserId = "me"

    // MARK: - Helpers

    private func makeSUT(
        match: MatchItem = .stub(),
        joinUseCase: JoinMatchUseCaseProtocol = MockJoinMatchUseCase(),
        subscribeUseCase: SubscribeMatchPlayersUseCaseProtocol = MockSubscribeMatchPlayersUseCase(),
        pendingPaymentStore: MockPendingPaymentStore = MockPendingPaymentStore(),
        fetchPendingPaymentUseCase: FetchPendingMatchPaymentUseCaseProtocol = MockFetchPendingMatchPaymentUseCase(),
        leaveUseCase: MockLeaveMatchUseCase = MockLeaveMatchUseCase(),
        authorizeSensitiveActionUseCase: MockAuthorizeSensitiveActionUseCase = MockAuthorizeSensitiveActionUseCase(),
        userId: String? = MatchDetailViewModelTests.currentUserId
    ) -> MatchDetailViewModel {
        MatchDetailViewModel(
            initialMatch: match,
            fetchDetailUseCase: MockFetchMatchDetailUseCase(),
            joinMatchUseCase: joinUseCase,
            pollPaymentStatusUseCase: MockPollPaymentStatusUseCase(),
            subscribePlayersUseCase: subscribeUseCase,
            cancelMatchUseCase: MockCancelMatchUseCase(),
            leaveMatchUseCase: leaveUseCase,
            pendingPaymentStore: pendingPaymentStore,
            fetchPendingPaymentUseCase: fetchPendingPaymentUseCase,
            fetchFieldAttributeCatalogsUseCase: MockFetchFieldAttributeCatalogsUseCase(),
            authorizeSensitiveActionUseCase: authorizeSensitiveActionUseCase,
            currentUserId: { userId }
        )
    }

    /// A snapshot where the current user holds a RESERVED spot expiring in `secondsFromNow`.
    private func reservedSnapshot(secondsFromNow: TimeInterval) -> MatchPlayersSnapshot {
        MatchPlayersSnapshot.stub(
            teamA: [MatchPlayer(
                id: Self.currentUserId,
                playerId: Self.currentUserId,
                name: "Me",
                status: .reserved
            )],
            reservations: [Self.currentUserId: Date().addingTimeInterval(secondsFromNow)]
        )
    }

    // MARK: - subscribeToPlayers: final states bypass Firestore

    func test_subscribeToPlayers_canceledMatch_populatesFromMatchRoster_withoutCallingFirestore() async {
        let player = MatchPlayer(id: "p1", playerId: "p1", name: "Alice", status: .joined)
        let match = MatchItem.stub(
            teamAPlayers: [player],
            matchStatus: .canceled
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
            matchStatus: .completed
        )
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(sut.liveTeamBPlayers, [player])
        XCTAssertEqual(subscribeUseCase.callCount, 0, "Firestore must not be subscribed for a completed match")
    }

    func test_subscribeToPlayers_cancelledVariant_bypasses_firestore() async {
        // Backend may return "CANCELLED" (double-L)
        let match = MatchItem.stub(matchStatus: .canceled)
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(subscribeUseCase.callCount, 0)
    }

    func test_subscribeToPlayers_scheduledMatch_subscribesToFirestore() async {
        let snapshot = MatchPlayersSnapshot.stub(teamA: [.stub()])
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [snapshot]
        let match = MatchItem.stub(matchStatus: .scheduled)
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(subscribeUseCase.callCount, 1, "Firestore must be subscribed for active matches")
        XCTAssertEqual(sut.liveTeamAPlayers, snapshot.teamAPlayers)
    }

    // MARK: - Capacity is fixed, never derived from the live roster

    /// Regression: a player leaving used to shrink the rendered capacity of
    /// BOTH teams, because the lineup derived it from the frozen
    /// `match.spotsLeft` plus the live Firestore counts — the total dropped by
    /// one and the `/ 2` truncated it away (5v5 → 4v4).
    func test_liveSnapshot_playerLeaves_doesNotChangeTeamCapacity() async {
        let fullTeam = (1...5).map { MatchPlayer.stub(id: "a\($0)") }
        let match = MatchItem.stub(
            spotsLeft: 0,
            teamAPlayers: fullTeam,
            teamBPlayers: (1...5).map { MatchPlayer.stub(id: "b\($0)") },
            teamAMax: 5,
            teamBMax: 5,
            matchStatus: .scheduled
        )
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        // Abraham (a5) leaves team A.
        subscribeUseCase.snapshotsToEmit = [
            .stub(
                teamA: Array(fullTeam.dropLast()),
                teamB: (1...5).map { MatchPlayer.stub(id: "b\($0)") }
            )
        ]
        let sut = makeSUT(match: match, subscribeUseCase: subscribeUseCase)

        await sut.subscribeToPlayers()

        XCTAssertEqual(sut.liveTeamAPlayers?.count, 4, "Team A must lose the leaver")
        XCTAssertEqual(sut.liveTeamBPlayers?.count, 5, "Team B must be untouched")
        XCTAssertEqual(sut.match.teamAMax, 5, "Capacity is fixed — the live roster must not shrink it")
        XCTAssertEqual(sut.match.teamBMax, 5, "Team B capacity must not move when someone leaves team A")
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

    // MARK: - Payment Security Gate

    func test_authorizePayment_whenAuthorizeSucceeds_returnsTrue() async {
        let authorize = MockAuthorizeSensitiveActionUseCase()
        let sut = makeSUT(authorizeSensitiveActionUseCase: authorize)

        let authorized = await sut.authorizePayment()

        XCTAssertTrue(authorized)
        XCTAssertEqual(authorize.callCount, 1)
        XCTAssertFalse(sut.isVerifyingPaymentSecurity)
    }

    func test_authorizePayment_whenAuthorizeFails_returnsFalse() async {
        let authorize = MockAuthorizeSensitiveActionUseCase()
        authorize.result = .failure(BiometricAuthError.failed)
        let sut = makeSUT(authorizeSensitiveActionUseCase: authorize)

        let authorized = await sut.authorizePayment()

        XCTAssertFalse(authorized)
        XCTAssertFalse(sut.isVerifyingPaymentSecurity)
    }

    // MARK: - Pending payment recovery: local cache first

    func test_reservedWithCachedPayment_usesCache_withoutCallingBackend() async {
        let cached = JoinMatchData.stub(paymentId: "cached-1")
        let store = MockPendingPaymentStore()
        store.stubbedData = cached
        let recovery = MockFetchPendingMatchPaymentUseCase()
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [reservedSnapshot(secondsFromNow: 300)]

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            pendingPaymentStore: store,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()

        XCTAssertEqual(sut.joinData, cached)
        XCTAssertEqual(recovery.executeCallCount, 0, "A local cache hit must not create a Stripe CustomerSession")
    }

    func test_reservedWithoutCache_recoversFromBackendAndPersists() async {
        let recovered = JoinMatchData.stub(paymentId: "recovered-1")
        let store = MockPendingPaymentStore()
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .recovered(recovered)
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [reservedSnapshot(secondsFromNow: 300)]

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            pendingPaymentStore: store,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()
        await waitForPendingRecovery(sut)

        XCTAssertEqual(sut.joinData, recovered)
        XCTAssertEqual(store.savedData, recovered, "Recovered data must be cached for the next launch")
        XCTAssertEqual(recovery.executeCallCount, 1)
        XCTAssertNil(sut.pendingPaymentIssue)
    }

    func test_reservedWithoutCache_recoveryRunsOnceAcrossManySnapshots() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .unavailable
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = (0..<5).map { _ in reservedSnapshot(secondsFromNow: 300) }

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()
        await waitForPendingRecovery(sut)

        XCTAssertEqual(recovery.executeCallCount, 1, "Firestore emits constantly — recovery must fire once per reservation")
    }

    func test_notRecoverable_onLiveReservation_raisesDialogWithBackendMessage() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .notRecoverable(message: "No se puede recuperar")
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [reservedSnapshot(secondsFromNow: 300)]

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()
        await waitForPendingRecovery(sut)

        XCTAssertEqual(sut.pendingPaymentIssue, .notRecoverable("No se puede recuperar"))
        XCTAssertNil(sut.joinData)
    }

    // MARK: - Pending payment recovery: expiring reservations must stay silent

    /// Regression: the reservation ran out, the local countdown cleared the cached
    /// payment, and the next Firestore snapshot — still listing the user as RESERVED
    /// because the backend hadn't released the spot yet — fired a recovery that came
    /// back 409 and raised a "payment cannot be recovered" dialog at a user who was
    /// simply being dropped from the match and could just join again.
    func test_reservationAlreadyExpired_doesNotAttemptRecovery() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .notRecoverable(message: "La reserva ya venció")
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [reservedSnapshot(secondsFromNow: -1)]

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()
        await waitForPendingRecovery(sut)

        XCTAssertEqual(recovery.executeCallCount, 0)
        XCTAssertNil(sut.pendingPaymentIssue, "An expired reservation must not raise any dialog")
    }

    /// Same guard, one second before expiry: a window too short to complete a Stripe
    /// payment is treated as already gone.
    func test_reservationExpiringWithinGraceWindow_doesNotAttemptRecovery() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        let subscribeUseCase = MockSubscribeMatchPlayersUseCase()
        subscribeUseCase.snapshotsToEmit = [reservedSnapshot(secondsFromNow: 5)]

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        await sut.subscribeToPlayers()
        await waitForPendingRecovery(sut)

        XCTAssertEqual(recovery.executeCallCount, 0)
        XCTAssertNil(sut.pendingPaymentIssue)
    }

    /// The backend releasing the spot must take the dialog down with it.
    func test_reservationReleasedAfterDialog_clearsTheDialog() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .notRecoverable(message: "No se puede recuperar")
        let subscribeUseCase = ControllableSubscribeMatchPlayersUseCase()

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        let streaming = Task { await sut.subscribeToPlayers() }
        // The task above must reach `execute` before emitting, or the snapshot is dropped.
        await waitUntil { subscribeUseCase.callCount > 0 }

        subscribeUseCase.emit(reservedSnapshot(secondsFromNow: 300))
        await waitUntil { sut.pendingPaymentIssue != nil }
        XCTAssertEqual(sut.pendingPaymentIssue, .notRecoverable("No se puede recuperar"))

        // The backend drops the user: no reservation in the next snapshot.
        subscribeUseCase.emit(.stub())
        await waitUntil { sut.currentUserReservedUntil == nil }

        XCTAssertNil(sut.pendingPaymentIssue, "Dialog must not survive the reservation it referred to")

        subscribeUseCase.finish()
        await streaming.value
    }

    // MARK: - Pending payment recovery: must not race a join in flight

    /// Regression: the backend publishes the RESERVED slot to Firestore before
    /// `POST /match/{id}/join` returns. The snapshot arrived with `joinData` still nil,
    /// fired a recovery for a payment the backend hadn't finished creating, got a 404,
    /// and stacked a "Payment Cannot Be Recovered" dialog on top of the "your spot is
    /// reserved" overlay of a reservation that was perfectly healthy.
    func test_reservationSnapshotWhileJoinInFlight_doesNotAttemptRecovery() async {
        let recovery = MockFetchPendingMatchPaymentUseCase()
        recovery.result = .notRecoverable(message: "No se pudieron encontrar los detalles del pago solicitado.")
        let joinUseCase = ControllableJoinMatchUseCase()
        let subscribeUseCase = ControllableSubscribeMatchPlayersUseCase()

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            joinUseCase: joinUseCase,
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        let streaming = Task { await sut.subscribeToPlayers() }
        await waitUntil { subscribeUseCase.callCount > 0 }

        let joining = Task { await sut.joinMatch(team: nil) }
        await waitUntil { sut.isJoining }

        // Firestore sees the reservation before the join call returns.
        subscribeUseCase.emit(reservedSnapshot(secondsFromNow: 300))
        await waitUntil { sut.currentUserReservedUntil != nil }

        XCTAssertEqual(recovery.executeCallCount, 0, "The join response carries the payment data — recovery must not race it")

        joinUseCase.complete(with: .success(.stub(paymentId: "join-1")))
        await joining.value
        await waitForPendingRecovery(sut)

        XCTAssertEqual(sut.joinData, .stub(paymentId: "join-1"))
        XCTAssertNil(sut.pendingPaymentIssue, "A healthy reservation must not raise a recovery dialog")

        subscribeUseCase.finish()
        await streaming.value
    }

    /// Same race, the other ordering: recovery was already in flight when the join
    /// response landed. Its (stale) answer must be dropped rather than raising a dialog
    /// over the payment data the join just delivered.
    func test_joinCompletesWhileRecoveryInFlight_dropsTheRecoveryOutcome() async {
        let recovery = ControllableFetchPendingMatchPaymentUseCase()
        let subscribeUseCase = ControllableSubscribeMatchPlayersUseCase()

        let sut = makeSUT(
            match: .stub(matchStatus: .scheduled),
            subscribeUseCase: subscribeUseCase,
            fetchPendingPaymentUseCase: recovery
        )
        let streaming = Task { await sut.subscribeToPlayers() }
        await waitUntil { subscribeUseCase.callCount > 0 }

        subscribeUseCase.emit(reservedSnapshot(secondsFromNow: 300))
        await waitUntil { sut.isRecoveringPayment }

        // The join lands first, with the authoritative payment data.
        await sut.joinMatch(team: nil)
        XCTAssertNotNil(sut.joinData)

        recovery.complete(with: .notRecoverable(message: "No se pudieron encontrar los detalles del pago solicitado."))
        await waitForPendingRecovery(sut)

        XCTAssertNil(sut.pendingPaymentIssue, "A recovery answer that lost the race to the join must be discarded")

        subscribeUseCase.finish()
        await streaming.value
    }

    // MARK: - Async helpers

    /// Recovery runs in a detached `Task` so the Firestore stream isn't stalled — give it
    /// turns to settle before asserting on its effects.
    private func waitForPendingRecovery(
        _ sut: MatchDetailViewModel,
        timeout: TimeInterval = 1
    ) async {
        await waitUntil(timeout: timeout) { !sut.isRecoveringPayment }
        await Task.yield()
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
    }
}

// MARK: - ControllableSubscribeMatchPlayersUseCase

/// Lets a test drive the Firestore stream snapshot by snapshot, so ordering between
/// snapshots and the async recovery task is deterministic.
private final class ControllableSubscribeMatchPlayersUseCase: SubscribeMatchPlayersUseCaseProtocol {
    private var continuation: AsyncThrowingStream<MatchPlayersSnapshot, Error>.Continuation?
    private(set) var callCount = 0

    func execute(matchId: String) -> AsyncThrowingStream<MatchPlayersSnapshot, Error> {
        callCount += 1
        // The build closure runs synchronously, so `emit` is usable right after this returns.
        return AsyncThrowingStream { self.continuation = $0 }
    }

    func emit(_ snapshot: MatchPlayersSnapshot) { continuation?.yield(snapshot) }
    func finish() { continuation?.finish() }
}

// MARK: - ControllableJoinMatchUseCase

/// Suspends inside `execute` so a test can hold a join in flight while Firestore emits.
private final class ControllableJoinMatchUseCase: JoinMatchUseCaseProtocol {
    private var continuation: CheckedContinuation<JoinMatchData, Error>?
    private(set) var callCount = 0

    func execute(matchId: String, team: String?) async throws -> JoinMatchData {
        callCount += 1
        return try await withCheckedThrowingContinuation { self.continuation = $0 }
    }

    func complete(with result: Result<JoinMatchData, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - ControllableFetchPendingMatchPaymentUseCase

/// Suspends inside `execute` so a test can decide when the recovery answer lands
/// relative to the join response.
private final class ControllableFetchPendingMatchPaymentUseCase: FetchPendingMatchPaymentUseCaseProtocol {
    private var continuation: CheckedContinuation<PendingPaymentRecovery, Never>?
    private(set) var executeCallCount = 0

    func execute(matchId: String) async -> PendingPaymentRecovery {
        executeCallCount += 1
        return await withCheckedContinuation { self.continuation = $0 }
    }

    func complete(with result: PendingPaymentRecovery) {
        continuation?.resume(returning: result)
        continuation = nil
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
