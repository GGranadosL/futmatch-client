import XCTest
@testable import PlayerFeature

final class NotificationCounterUseCasesTests: XCTestCase {

    // MARK: - RefreshNotificationInboxUseCase

    func test_refresh_marksRead_reloadsHistory_thenReconcilesCounterWithServer() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 2
        repo.refreshNotificationsResult = .success([.stub(id: "a"), .stub(id: "b")])
        repo.refreshUnreadCountResult = .success(1) // arrived on another device meanwhile

        let inbox = try await RefreshNotificationInboxUseCase(repository: repo).execute()

        XCTAssertEqual(repo.markAllReadCallCount, 1)
        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
        XCTAssertEqual(repo.refreshUnreadCountCallCount, 1)
        XCTAssertEqual(inbox.items.count, 2)
        XCTAssertEqual(inbox.unreadCount, 1)
    }

    func test_refresh_stillLoadsHistory_whenMarkAllReadFails() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 2
        repo.markAllReadResult = .failure(TestError.boom)
        repo.refreshNotificationsResult = .success([.stub()])
        repo.refreshUnreadCountResult = .success(2)

        let inbox = try await RefreshNotificationInboxUseCase(repository: repo).execute()

        XCTAssertEqual(inbox.items.count, 1)
        XCTAssertEqual(inbox.unreadCount, 2)
    }

    func test_refresh_keepsCounter_whenUnreadCountRequestFails() async throws {
        let repo = MockNotificationRepository()
        repo.refreshNotificationsResult = .success([.stub()])
        repo.refreshUnreadCountResult = .failure(TestError.boom)

        let inbox = try await RefreshNotificationInboxUseCase(repository: repo).execute()

        XCTAssertEqual(inbox.items.count, 1)
        XCTAssertEqual(inbox.unreadCount, 0)
    }

    // MARK: - RegisterIncomingNotificationUseCase

    func test_registerIncoming_incrementsByOne_withoutAnyRequest() {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 4
        let sut = RegisterIncomingNotificationUseCase(repository: repo)

        XCTAssertEqual(sut.execute(), 5)
        XCTAssertEqual(sut.execute(), 6)
        XCTAssertEqual(repo.refreshUnreadCountCallCount, 0)
        XCTAssertEqual(repo.refreshNotificationsCallCount, 0)
    }

    // MARK: - ClearNotificationStateUseCase

    func test_clear_dropsHistoryAndCounter() {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 7
        repo.cachedNotifications = [.stub()]

        ClearNotificationStateUseCase(repository: repo).execute()

        XCTAssertEqual(repo.clearCallCount, 1)
        XCTAssertEqual(repo.cachedUnreadCount, 0)
        XCTAssertTrue(repo.cachedNotifications.isEmpty)
    }
}
