import XCTest
@testable import PlayerFeature

// MARK: - NotificationsViewModelTests

@MainActor
final class NotificationsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        notificationService: MockNotificationService = MockNotificationService(),
        fetchNotificationsUseCase: MockFetchNotificationsUseCase = MockFetchNotificationsUseCase(),
        seenStore: MockSeenNotificationStore = MockSeenNotificationStore()
    ) -> NotificationsViewModel {
        NotificationsViewModel(
            notificationService: notificationService,
            fetchNotificationsUseCase: fetchNotificationsUseCase,
            fetchMatchDetailUseCase: MockFetchMatchDetailUseCase(),
            seenStore: seenStore
        )
    }

    /// N distinct unread notifications, `n-0`…`n-<count-1>`.
    private func unreadItems(_ count: Int) -> [NotificationItem] {
        (0..<count).map { .stub(id: "n-\($0)", isRead: false) }
    }

    /// Polls until `condition()` is true or `timeout` elapses — used to await
    /// the Combine `.sink { Task { ... } }` hop triggered by a NotificationCenter post.
    private func waitUntil(
        timeout: TimeInterval = 1.0,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    // MARK: - load()

    func test_load_firstCall_forcesFetch_evenWithoutExplicitForceRefresh() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success([.stub()])
        let sut = makeSUT(fetchNotificationsUseCase: useCase)

        await sut.load()

        XCTAssertEqual(useCase.lastForceRefresh, true, "First-ever load must bypass the safety-net throttle since there's nothing displayable yet")
        if case .loaded = sut.state {} else { XCTFail("Expected .loaded, got \(sut.state)") }
    }

    func test_load_secondCall_keepsShowingData_whenUseCaseSkips() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success([.stub(id: "n-1")])
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.load()

        useCase.result = .success(nil) // simulate the safety-net throttle kicking in
        await sut.load()

        XCTAssertEqual(useCase.lastForceRefresh, false, "Already has data — shouldn't force through the throttle")
        if case .loaded(let sections) = sut.state {
            XCTAssertEqual(sections.first?.notifications.first?.id, "n-1", "Stale-but-valid data should remain visible")
        } else {
            XCTFail("Expected .loaded to persist, got \(sut.state)")
        }
    }

    func test_load_forceRefresh_passesThrough_regardlessOfExistingData() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success([.stub()])
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.load()

        await sut.load(forceRefresh: true)

        XCTAssertEqual(useCase.lastForceRefresh, true)
    }

    // MARK: - loadUnreadCount()

    func test_loadUnreadCount_ignoresNilResult_keepsPreviousCount() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success([.stub(isRead: false), .stub(id: "n-2", isRead: false)])
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.loadUnreadCount()
        let countAfterFirstLoad = sut.unreadCount

        useCase.result = .success(nil) // throttled
        await sut.loadUnreadCount()

        XCTAssertEqual(sut.unreadCount, countAfterFirstLoad, "A throttled (nil) result must not reset the badge")
    }

    // MARK: - Badge: seen-ID bookkeeping

    func test_loadUnreadCount_countsEveryNotificationNotYetSeen() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let sut = makeSUT(fetchNotificationsUseCase: useCase)

        await sut.loadUnreadCount()

        XCTAssertEqual(sut.unreadCount, 11)
    }

    /// The regression this whole change exists for: opening the screen must clear the
    /// badge for good even if the `load()` that follows never lands.
    func test_markAsSeen_persistsImmediately_withoutAFollowUpLoad() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let store = MockSeenNotificationStore()
        let sut = makeSUT(fetchNotificationsUseCase: useCase, seenStore: store)
        await sut.loadUnreadCount()

        sut.markAsSeen() // screen opened; no load() runs at all

        XCTAssertEqual(store.seenIds.count, 11, "Seen IDs must be persisted eagerly, not by the load() that follows")
        await sut.loadUnreadCount(forceRefresh: true)
        XCTAssertEqual(sut.unreadCount, 0, "The badge must not come back after the user has seen them")
    }

    func test_markAsSeen_badgeStaysCleared_whenFollowUpLoadIsThrottled() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.loadUnreadCount()

        sut.markAsSeen()
        useCase.result = .success(nil) // safety-net throttle swallows the screen's load()
        await sut.load()

        useCase.result = .success(unreadItems(11))
        await sut.loadUnreadCount(forceRefresh: true)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_markAsSeen_badgeStaysCleared_whenFollowUpLoadIsCancelled() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.loadUnreadCount()

        sut.markAsSeen()
        useCase.result = .failure(CancellationError()) // user tapped back mid-flight
        await sut.load()

        useCase.result = .success(unreadItems(11))
        await sut.loadUnreadCount(forceRefresh: true)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_loadUnreadCount_countsOnlyTheNewNotification_afterTheRestWereSeen() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.loadUnreadCount()
        sut.markAsSeen()

        useCase.result = .success(unreadItems(11) + [.stub(id: "n-new", isRead: false)])
        await sut.loadUnreadCount(forceRefresh: true)

        XCTAssertEqual(sut.unreadCount, 1)
    }

    /// The mirror bug of the old count-diff scheme: deleting notifications used to
    /// drag the baseline out of sync and could suppress the badge forever after.
    func test_loadUnreadCount_stillReportsNewNotification_afterSomeWereDeleted() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let sut = makeSUT(fetchNotificationsUseCase: useCase)
        await sut.load() // populates state so delete() can prune the sections too
        sut.markAsSeen()

        for index in 0..<5 { await sut.delete(id: "n-\(index)") }

        let remaining = (5..<11).map { NotificationItem.stub(id: "n-\($0)", isRead: false) }
        useCase.result = .success(remaining + [.stub(id: "n-new", isRead: false)])
        await sut.loadUnreadCount(forceRefresh: true)

        XCTAssertEqual(sut.unreadCount, 1)
    }

    func test_loadUnreadCount_prunesSeenIdsTheServerNoLongerReturns() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let store = MockSeenNotificationStore()
        let sut = makeSUT(fetchNotificationsUseCase: useCase, seenStore: store)
        await sut.loadUnreadCount()
        sut.markAsSeen()

        useCase.result = .success(unreadItems(3))
        await sut.loadUnreadCount(forceRefresh: true)

        XCTAssertEqual(store.seenIds, ["n-0", "n-1", "n-2"], "Seen IDs must not accumulate past what the feed still returns")
    }

    func test_clearOnLogout_wipesSeenIds_soTheNextAccountCountsFromScratch() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success(unreadItems(11))
        let store = MockSeenNotificationStore()
        let sut = makeSUT(fetchNotificationsUseCase: useCase, seenStore: store)
        await sut.loadUnreadCount()
        sut.markAsSeen()

        sut.clearOnLogout()

        XCTAssertTrue(store.seenIds.isEmpty)
        XCTAssertEqual(sut.unreadCount, 0)
        await sut.loadUnreadCount(forceRefresh: true)
        XCTAssertEqual(sut.unreadCount, 11)
    }

    // MARK: - Push-driven refresh

    func test_pushNotificationReceived_forcesUnreadCountRefresh() async {
        let useCase = MockFetchNotificationsUseCase()
        useCase.result = .success([.stub(isRead: false)])
        let sut = makeSUT(fetchNotificationsUseCase: useCase)

        NotificationCenter.default.post(name: .inAppNotificationsPushReceived, object: nil)
        await waitUntil { useCase.executeCallCount > 0 }

        XCTAssertEqual(useCase.executeCallCount, 1)
        XCTAssertEqual(useCase.lastForceRefresh, true, "A push must bypass the safety-net throttle")
        _ = sut // keep the view model (and its Combine subscription) alive until assertions run
    }
}
