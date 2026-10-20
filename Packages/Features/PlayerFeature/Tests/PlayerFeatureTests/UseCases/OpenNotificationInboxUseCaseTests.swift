import XCTest
@testable import PlayerFeature

final class OpenNotificationInboxUseCaseTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeSUT(_ repo: MockNotificationRepository) -> OpenNotificationInboxUseCase {
        OpenNotificationInboxUseCase(repository: repo, cacheTimeToLive: 900, now: { self.now })
    }

    func test_execute_readsCounterBeforeMarkingAllRead() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 3
        repo.cachedNotifications = [.stub(id: "a")]
        repo.lastFetchedAt = now

        _ = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.unreadCountAtMarkAllRead, 3)
    }

    func test_execute_refreshesHistory_whenThereWereUnreadNotifications_evenIfCacheIsFresh() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 1
        repo.cachedNotifications = [.stub(id: "a")]
        repo.lastFetchedAt = now
        repo.refreshNotificationsResult = .success([.stub(id: "a"), .stub(id: "new")])

        let inbox = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
        XCTAssertEqual(inbox.items.map(\.id), ["a", "new"])
        XCTAssertEqual(inbox.unreadCount, 0)
    }

    func test_execute_refreshesHistory_whenCounterIsZeroButNothingIsCached() async throws {
        let repo = MockNotificationRepository()
        repo.lastFetchedAt = now

        _ = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
    }

    func test_execute_refreshesHistory_whenCacheWasNeverFetched() async throws {
        let repo = MockNotificationRepository()
        repo.cachedNotifications = [.stub()]
        repo.lastFetchedAt = nil

        _ = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
    }

    func test_execute_skipsRefresh_whenCounterIsZeroAndCacheIsWithinTimeToLive() async throws {
        let repo = MockNotificationRepository()
        repo.cachedNotifications = [.stub(id: "a")]
        repo.lastFetchedAt = now.addingTimeInterval(-899)

        let inbox = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshNotificationsCallCount, 0)
        XCTAssertEqual(inbox.items.map(\.id), ["a"])
    }

    func test_execute_refreshesHistory_whenCacheIsOlderThanTimeToLive() async throws {
        let repo = MockNotificationRepository()
        repo.cachedNotifications = [.stub(id: "a")]
        repo.lastFetchedAt = now.addingTimeInterval(-900)

        _ = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
    }

    func test_execute_neverAsksForTheUnreadCountEndpoint() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 2

        _ = try await makeSUT(repo).execute()

        XCTAssertEqual(repo.refreshUnreadCountCallCount, 0)
    }

    func test_execute_keepsBadgeAndStillRefreshes_whenMarkAllReadFails() async throws {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 4
        repo.cachedNotifications = [.stub(id: "a", isRead: false)]
        repo.markAllReadResult = .failure(TestError.boom)
        repo.refreshNotificationsResult = .success([.stub(id: "a", isRead: false)])

        let inbox = try await makeSUT(repo).execute()

        XCTAssertEqual(inbox.unreadCount, 4, "A failed mark-as-read must not clear the badge")
        XCTAssertEqual(repo.refreshNotificationsCallCount, 1)
    }

    func test_execute_propagatesHistoryError() async {
        let repo = MockNotificationRepository()
        repo.cachedUnreadCount = 1
        repo.refreshNotificationsResult = .failure(TestError.boom)

        do {
            _ = try await makeSUT(repo).execute()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
