import XCTest
@testable import PlayerFeature

// MARK: - NotificationsViewModelTests

@MainActor
final class NotificationsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        notificationService: MockNotificationService = MockNotificationService(),
        fetchNotificationsUseCase: MockFetchNotificationsUseCase = MockFetchNotificationsUseCase()
    ) -> NotificationsViewModel {
        NotificationsViewModel(
            notificationService: notificationService,
            fetchNotificationsUseCase: fetchNotificationsUseCase,
            fetchMatchDetailUseCase: MockFetchMatchDetailUseCase()
        )
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
