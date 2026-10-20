import XCTest
@testable import PlayerFeature

final class NotificationRepositoryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func makeSUT(
        service: MockNotificationService = MockNotificationService(),
        cache: MockNotificationCacheStore = MockNotificationCacheStore()
    ) -> NotificationRepository {
        NotificationRepository(service: service, cache: cache, now: { self.now })
    }

    func test_refreshNotifications_replacesCacheAndStampsTime_butLeavesCounter() async throws {
        let service = MockNotificationService()
        service.fetchNotificationsResult = .success([.stub(id: "a")])
        let cache = MockNotificationCacheStore()
        cache.unreadCount = 3

        _ = try await makeSUT(service: service, cache: cache).refreshNotifications()

        XCTAssertEqual(cache.notifications.map(\.id), ["a"])
        XCTAssertEqual(cache.lastFetchedAt, now)
        XCTAssertEqual(cache.unreadCount, 3)
    }

    func test_refreshNotifications_keepsCache_whenRequestFails() async {
        let service = MockNotificationService()
        service.fetchNotificationsResult = .failure(TestError.boom)
        let cache = MockNotificationCacheStore()
        cache.notifications = [.stub(id: "old")]

        _ = try? await makeSUT(service: service, cache: cache).refreshNotifications()

        XCTAssertEqual(cache.notifications.map(\.id), ["old"])
    }

    func test_refreshUnreadCount_storesServerValue() async throws {
        let service = MockNotificationService()
        service.unreadCountResult = .success(9)
        let cache = MockNotificationCacheStore()

        let count = try await makeSUT(service: service, cache: cache).refreshUnreadCount()

        XCTAssertEqual(count, 9)
        XCTAssertEqual(cache.unreadCount, 9)
    }

    func test_markAllAsRead_zeroesCounterAndFlagsCache_evenWhenServerMarkedNone() async throws {
        let service = MockNotificationService()
        service.markAllReadResult = .success(0)
        let cache = MockNotificationCacheStore()
        cache.unreadCount = 2
        cache.notifications = [.stub(isRead: false)]

        try await makeSUT(service: service, cache: cache).markAllAsRead()

        XCTAssertEqual(cache.unreadCount, 0)
        XCTAssertEqual(cache.notifications.map(\.isRead), [true])
    }

    func test_markAllAsRead_leavesCounterAndCacheUntouched_whenRequestFails() async {
        let service = MockNotificationService()
        service.markAllReadResult = .failure(TestError.boom)
        let cache = MockNotificationCacheStore()
        cache.unreadCount = 2
        cache.notifications = [.stub(isRead: false)]

        try? await makeSUT(service: service, cache: cache).markAllAsRead()

        XCTAssertEqual(cache.unreadCount, 2)
        XCTAssertEqual(cache.notifications.map(\.isRead), [false])
    }

    func test_deleteNotification_removesFromCacheOnlyAfterServerSucceeds() async {
        let service = MockNotificationService()
        service.deleteResult = .failure(TestError.boom)
        let cache = MockNotificationCacheStore()
        cache.notifications = [.stub(id: "a")]
        let sut = makeSUT(service: service, cache: cache)

        try? await sut.deleteNotification(id: "a")
        XCTAssertEqual(cache.notifications.map(\.id), ["a"])

        service.deleteResult = .success(())
        try? await sut.deleteNotification(id: "a")
        XCTAssertTrue(cache.notifications.isEmpty)
    }

    func test_registerIncomingNotification_addsOneToStoredCounter() {
        let cache = MockNotificationCacheStore()
        cache.unreadCount = 4

        let count = makeSUT(cache: cache).registerIncomingNotification()

        XCTAssertEqual(count, 5)
        XCTAssertEqual(cache.unreadCount, 5)
    }
}
