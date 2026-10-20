import XCTest
@testable import PlayerFeature

// MARK: - NotificationsViewModelTests

@MainActor
final class NotificationsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        repository: MockNotificationRepository = MockNotificationRepository(),
        service: MockNotificationService = MockNotificationService()
    ) -> NotificationsViewModel {
        NotificationsViewModel(
            loadCachedUseCase: LoadCachedNotificationsUseCase(repository: repository),
            fetchUnreadCountUseCase: FetchUnreadNotificationCountUseCase(repository: repository),
            openInboxUseCase: OpenNotificationInboxUseCase(repository: repository),
            refreshInboxUseCase: RefreshNotificationInboxUseCase(repository: repository),
            deleteNotificationUseCase: DeleteNotificationUseCase(repository: repository),
            registerIncomingUseCase: RegisterIncomingNotificationUseCase(repository: repository),
            clearStateUseCase: ClearNotificationStateUseCase(repository: repository),
            fetchMatchDetailUseCase: MockFetchMatchDetailUseCase()
        )
    }

    /// Polls until `condition()` is true or `timeout` elapses — used to await
    /// the Combine `.sink` hop triggered by a NotificationCenter post.
    private func waitUntil(
        timeout: TimeInterval = 1.0,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    // MARK: - Badge

    func test_init_showsTheLastKnownCounterBeforeAnyRequest() {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 6

        let sut = makeSUT(repository: repo)

        XCTAssertEqual(sut.unreadCount, 6)
        XCTAssertEqual(repo.refreshUnreadCountCallCount, 0)
    }

    func test_loadUnreadCountForSession_requestsTheServerCount() async {
        let repo = MockNotificationRepository()
        repo.refreshUnreadCountResult = .success(11)
        let sut = makeSUT(repository: repo)

        await sut.loadUnreadCountForSession()

        XCTAssertEqual(sut.unreadCount, 11)
    }

    func test_loadUnreadCountForSession_asksOnlyOncePerSession() async {
        let repo = MockNotificationRepository()
        repo.refreshUnreadCountResult = .success(2)
        let sut = makeSUT(repository: repo)

        await sut.loadUnreadCountForSession()
        await sut.loadUnreadCountForSession()

        XCTAssertEqual(repo.refreshUnreadCountCallCount, 1)
    }

    func test_loadUnreadCountForSession_retriesLater_whenTheRequestFailed() async {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 3
        repo.refreshUnreadCountResult = .failure(TestError.boom)
        let sut = makeSUT(repository: repo)

        await sut.loadUnreadCountForSession()
        XCTAssertEqual(sut.unreadCount, 3, "A failure must leave the badge as it was")

        repo.refreshUnreadCountResult = .success(4)
        await sut.loadUnreadCountForSession()
        XCTAssertEqual(sut.unreadCount, 4)
    }

    func test_userPush_incrementsBadgeLocally_withoutAnyRequest() async {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 2
        let sut = makeSUT(repository: repo)

        NotificationCenter.default.post(name: .inAppNotificationsPushReceived, object: nil)
        await waitUntil { sut.unreadCount == 3 }

        XCTAssertEqual(sut.unreadCount, 3)
        XCTAssertEqual(repo.refreshUnreadCountCallCount, 0)
        XCTAssertEqual(repo.refreshNotificationsCallCount, 0)
    }

    // MARK: - open()

    func test_open_clearsBadge_andShowsServerHistory() async {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 2
        repo.refreshNotificationsResult = .success([.stub(id: "a"), .stub(id: "b")])
        let sut = makeSUT(repository: repo)

        await sut.open()

        XCTAssertEqual(sut.unreadCount, 0)
        guard case .loaded(let sections) = sut.state else { return XCTFail("Expected .loaded, got \(sut.state)") }
        XCTAssertEqual(sections.flatMap(\.notifications).count, 2)
    }

    func test_open_isEmpty_whenServerHasNoNotifications() async {
        let sut = makeSUT()

        await sut.open()

        guard case .empty = sut.state else { return XCTFail("Expected .empty, got \(sut.state)") }
    }

    func test_open_showsCachedListInsteadOfFailing_whenTheRefreshErrors() async {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 1
        repo.cachedNotifications = [.stub(id: "cached")]
        repo.refreshNotificationsResult = .failure(TestError.boom)
        let sut = makeSUT(repository: repo)

        await sut.open()

        guard case .loaded(let sections) = sut.state else { return XCTFail("Expected .loaded, got \(sut.state)") }
        XCTAssertEqual(sections.first?.notifications.first?.id, "cached")
    }

    func test_open_fails_whenThereIsNothingCachedAndTheRequestErrors() async {
        let repo = MockNotificationRepository()
        repo.refreshNotificationsResult = .failure(TestError.boom)
        let sut = makeSUT(repository: repo)

        await sut.open()

        guard case .failed = sut.state else { return XCTFail("Expected .failed, got \(sut.state)") }
    }

    // MARK: - refresh()

    func test_refresh_reconcilesBadgeWithServer() async {
        let repo = MockNotificationRepository()
        repo.refreshNotificationsResult = .success([.stub()])
        repo.refreshUnreadCountResult = .success(5)
        let sut = makeSUT(repository: repo)
        await sut.open()

        await sut.refresh()

        XCTAssertEqual(sut.unreadCount, 5)
    }

    // MARK: - delete()

    func test_delete_removesTheRowImmediately_andFromTheCacheOnSuccess() async {
        let repo = MockNotificationRepository()
        repo.refreshNotificationsResult = .success([.stub(id: "a"), .stub(id: "b")])
        let sut = makeSUT(repository: repo)
        await sut.open()

        await sut.delete(id: "a")

        XCTAssertEqual(repo.deletedIds, ["a"])
        guard case .loaded(let sections) = sut.state else { return XCTFail("Expected .loaded, got \(sut.state)") }
        XCTAssertEqual(sections.flatMap(\.notifications).map(\.id), ["b"])
    }

    func test_delete_bringsTheRowBack_whenTheServerRejectsIt() async {
        let repo = MockNotificationRepository()
        repo.refreshNotificationsResult = .success([.stub(id: "a")])
        let sut = makeSUT(repository: repo)
        await sut.open()
        repo.deleteResult = .failure(TestError.boom)

        await sut.delete(id: "a")

        guard case .loaded(let sections) = sut.state else { return XCTFail("Expected .loaded, got \(sut.state)") }
        XCTAssertEqual(sections.flatMap(\.notifications).map(\.id), ["a"])
    }

    // MARK: - Logout

    func test_clearOnLogout_wipesStateAndCounter_andAllowsANewSessionCount() async {
        let repo = MockNotificationRepository()
        repo.refreshUnreadCountResult = .success(8)
        let sut = makeSUT(repository: repo)
        await sut.loadUnreadCountForSession()

        sut.clearOnLogout()

        XCTAssertEqual(repo.clearCallCount, 1)
        XCTAssertEqual(sut.unreadCount, 0)
        await sut.loadUnreadCountForSession()
        XCTAssertEqual(repo.refreshUnreadCountCallCount, 2, "The next account's session must ask again")
    }
}
