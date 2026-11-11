import XCTest
@testable import AdminFeature

final class OpenOperationalInboxUseCaseTests: XCTestCase {

    func test_knownZero_andNothingUnread_noReadAll() async throws {
        let repo = MockOperationalNotificationRepository()
        repo.notificationsResult = .success([.stub(isRead: true)])

        let snapshot = try await OpenOperationalInboxUseCase(repository: repo).execute(inbox: .admin, knownUnreadCount: 0)

        XCTAssertEqual(repo.calls, ["list:ADMIN"])
        XCTAssertNil(snapshot.reconciledUnreadCount)
    }

    func test_knownUnread_marksReadFirst_thenReReadsCount() async throws {
        let repo = MockOperationalNotificationRepository()
        repo.countResults = [.success(1)] // a push arrived while marking

        let snapshot = try await OpenOperationalInboxUseCase(repository: repo).execute(inbox: .organizer, knownUnreadCount: 3)

        XCTAssertEqual(repo.calls, ["read:ORGANIZER", "list:ORGANIZER", "count:ORGANIZER"])
        XCTAssertEqual(snapshot.reconciledUnreadCount, 1)
    }

    func test_staleZero_discoversUnread_andMarksInSameInbox() async throws {
        let repo = MockOperationalNotificationRepository()
        repo.notificationsResult = .success([.stub(isRead: false)])

        let snapshot = try await OpenOperationalInboxUseCase(repository: repo).execute(inbox: .admin, knownUnreadCount: 0)

        XCTAssertEqual(repo.calls, ["list:ADMIN", "read:ADMIN", "count:ADMIN"])
        XCTAssertEqual(snapshot.reconciledUnreadCount, 0)
    }

    func test_readAllFailure_keepsCounter_andReportsIt() async throws {
        let repo = MockOperationalNotificationRepository()
        repo.markResult = .failure(TestError.boom)

        let snapshot = try await OpenOperationalInboxUseCase(repository: repo).execute(inbox: .admin, knownUnreadCount: 2)

        XCTAssertTrue(snapshot.markReadFailed)
        XCTAssertNil(snapshot.reconciledUnreadCount)
        XCTAssertEqual(repo.calls, ["read:ADMIN", "list:ADMIN"], "No second read-all and no count after a failure")
    }

    func test_endpoints_alwaysCarryTheInbox() {
        XCTAssertEqual(OperationalNotificationEndpoint.unreadCount(inbox: .admin).queryItems?.first?.value, "ADMIN")
        XCTAssertEqual(OperationalNotificationEndpoint.markAllRead(inbox: .organizer).queryItems?.first?.value, "ORGANIZER")
        XCTAssertEqual(OperationalNotificationEndpoint.delete(id: "n", inbox: .admin).queryItems?.first?.value, "ADMIN")
        XCTAssertEqual(OperationalNotificationEndpoint.delete(id: "n", inbox: .admin).path, "/notification/n")
    }

    func test_inboxParsing_missingOrPlayerIsNotOperational() {
        XCTAssertEqual(OperationalInbox(raw: "admin"), .admin)
        XCTAssertNil(OperationalInbox(raw: "PLAYER"))
        XCTAssertNil(OperationalInbox(raw: nil))
    }

    func test_findMatch_usesTheInboxRoleList() async throws {
        let sut = FindOperationalMatchUseCase(
            adminMatches: StubMatchesList(result: .success([.stub(id: "a")])),
            organizerMatches: StubMatchesList(result: .success([.stub(id: "o")]))
        )
        let adminHit = try await sut.execute(matchId: "a", inbox: .admin)
        let organizerMiss = try await sut.execute(matchId: "a", inbox: .organizer)
        XCTAssertEqual(adminHit?.id, "a")
        XCTAssertNil(organizerMiss)
    }
}

@MainActor
final class OperationalNotificationsStoreTests: XCTestCase {

    func test_concurrentRefreshes_shareOneRequest() async {
        let repo = MockOperationalNotificationRepository()
        repo.countResults = [.success(4)]
        repo.countGate = { try? await Task.sleep(nanoseconds: 50_000_000) }
        let sut = OperationalNotificationsStore(
            fetchCountUseCase: FetchOperationalUnreadCountUseCase(repository: repo),
            notificationCenter: NotificationCenter()
        )

        async let first: Void = sut.refresh(.admin)
        async let second: Void = sut.refresh(.admin)
        _ = await (first, second)

        XCTAssertEqual(repo.countCallCount, 1)
        XCTAssertEqual(sut.count(for: .admin), 4)
    }

    func test_staleResponse_doesNotOverwriteNewerValue() async {
        let repo = MockOperationalNotificationRepository()
        repo.countResults = [.success(5)]
        repo.countGate = { try? await Task.sleep(nanoseconds: 50_000_000) }
        let sut = OperationalNotificationsStore(
            fetchCountUseCase: FetchOperationalUnreadCountUseCase(repository: repo),
            notificationCenter: NotificationCenter()
        )

        let refresh = Task { await sut.refresh(.admin) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        sut.set(0, for: .admin) // the hub just reconciled after read-all
        await refresh.value

        XCTAssertEqual(sut.count(for: .admin), 0)
    }

    func test_inboxesAreIndependent_andResetClearsAll() {
        let repo = MockOperationalNotificationRepository()
        let sut = OperationalNotificationsStore(
            fetchCountUseCase: FetchOperationalUnreadCountUseCase(repository: repo),
            notificationCenter: NotificationCenter()
        )
        sut.set(2, for: .admin)
        XCTAssertTrue(sut.hasUnread(.admin))
        XCTAssertFalse(sut.hasUnread(.organizer))

        sut.reset()

        XCTAssertNil(sut.count(for: .admin))
    }
}

@MainActor
final class OperationalNotificationsViewModelTests: XCTestCase {

    private func makeSUT(
        repo: MockOperationalNotificationRepository,
        store: OperationalNotificationsStore,
        matches: [AdminMatch] = []
    ) -> OperationalNotificationsViewModel {
        OperationalNotificationsViewModel(
            inbox: .admin,
            store: store,
            openInboxUseCase: OpenOperationalInboxUseCase(repository: repo),
            deleteUseCase: DeleteOperationalNotificationUseCase(repository: repo),
            findMatchUseCase: FindOperationalMatchUseCase(
                adminMatches: StubMatchesList(result: .success(matches)),
                organizerMatches: StubMatchesList(result: .success([]))
            ),
            matchUnavailableMessage: "gone"
        )
    }

    private func makeStore(_ repo: MockOperationalNotificationRepository) -> OperationalNotificationsStore {
        OperationalNotificationsStore(
            fetchCountUseCase: FetchOperationalUnreadCountUseCase(repository: repo),
            notificationCenter: NotificationCenter()
        )
    }

    func test_load_reconcilesStoreCount() async {
        let repo = MockOperationalNotificationRepository()
        repo.notificationsResult = .success([.stub()])
        repo.countResults = [.success(0)]
        let store = makeStore(repo)
        store.set(3, for: .admin)
        let sut = makeSUT(repo: repo, store: store)

        await sut.load()

        XCTAssertEqual(store.count(for: .admin), 0)
        XCTAssertEqual(sut.notifications?.map(\.id), ["n-1"])
    }

    func test_readAllFailure_keepsBadge_andShowsToast() async {
        let repo = MockOperationalNotificationRepository()
        repo.markResult = .failure(TestError.boom)
        let store = makeStore(repo)
        store.set(3, for: .admin)
        let sut = makeSUT(repo: repo, store: store)

        await sut.load()

        XCTAssertEqual(store.count(for: .admin), 3)
        XCTAssertNotNil(sut.toastError)
    }

    func test_tap_opensMatchFromAdminList_orReportsUnavailable() async {
        let repo = MockOperationalNotificationRepository()
        let sut = makeSUT(repo: repo, store: makeStore(repo), matches: [.stub(id: "m-1")])

        await sut.open(.stub(matchId: "m-1"))
        XCTAssertEqual(sut.matchToOpen?.id, "m-1")

        sut.didOpenMatch()
        await sut.open(.stub(matchId: "missing"))
        XCTAssertNil(sut.matchToOpen)
        XCTAssertEqual(sut.toastError, "gone")
    }

    func test_delete_usesSameInbox_andRemovesOnSuccessOnly() async {
        let repo = MockOperationalNotificationRepository()
        repo.notificationsResult = .success([.stub(id: "a"), .stub(id: "b")])
        let sut = makeSUT(repo: repo, store: makeStore(repo))
        await sut.load()

        repo.deleteResult = .failure(TestError.boom)
        await sut.delete(id: "a")
        XCTAssertEqual(sut.notifications?.count, 2)

        repo.deleteResult = .success(())
        await sut.delete(id: "a")
        XCTAssertEqual(sut.notifications?.map(\.id), ["b"])
        XCTAssertTrue(repo.calls.contains("delete:a:ADMIN"))
    }
}
