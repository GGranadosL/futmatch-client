import XCTest
@testable import PlayerFeature

final class FetchNotificationsUseCaseTests: XCTestCase {

    func test_execute_fetchesAndStampsTimestamp_whenNeverFetchedBefore() async throws {
        let service = MockNotificationService()
        let expected = [NotificationItem.stub(id: "n-1")]
        service.fetchNotificationsResult = .success(expected)
        let store = MockNotificationFetchTimestampStore()
        let sut = FetchNotificationsUseCase(notificationService: service, timestampStore: store, safetyNetInterval: 300)

        let result = try await sut.execute(forceRefresh: false)

        XCTAssertEqual(service.fetchNotificationsCallCount, 1)
        XCTAssertEqual(result?.map(\.id), expected.map(\.id))
        XCTAssertNotNil(store.lastFetchedAt)
    }

    func test_execute_skipsFetch_whenRecentlyFetchedAndNotForced() async throws {
        let service = MockNotificationService()
        let store = MockNotificationFetchTimestampStore()
        store.lastFetchedAt = Date() // just fetched
        let sut = FetchNotificationsUseCase(notificationService: service, timestampStore: store, safetyNetInterval: 300)

        let result = try await sut.execute(forceRefresh: false)

        XCTAssertNil(result)
        XCTAssertEqual(service.fetchNotificationsCallCount, 0)
    }

    func test_execute_fetches_whenStaleBeyondSafetyNetInterval() async throws {
        let service = MockNotificationService()
        service.fetchNotificationsResult = .success([.stub()])
        let store = MockNotificationFetchTimestampStore()
        store.lastFetchedAt = Date().addingTimeInterval(-301) // older than the 300s interval
        let sut = FetchNotificationsUseCase(notificationService: service, timestampStore: store, safetyNetInterval: 300)

        let result = try await sut.execute(forceRefresh: false)

        XCTAssertNotNil(result)
        XCTAssertEqual(service.fetchNotificationsCallCount, 1)
    }

    func test_execute_forceRefresh_alwaysFetches_ignoringRecentTimestamp() async throws {
        let service = MockNotificationService()
        service.fetchNotificationsResult = .success([.stub()])
        let store = MockNotificationFetchTimestampStore()
        store.lastFetchedAt = Date() // just fetched
        let sut = FetchNotificationsUseCase(notificationService: service, timestampStore: store, safetyNetInterval: 300)

        let result = try await sut.execute(forceRefresh: true)

        XCTAssertNotNil(result)
        XCTAssertEqual(service.fetchNotificationsCallCount, 1)
    }

    func test_execute_propagatesServiceError() async {
        let service = MockNotificationService()
        service.fetchNotificationsResult = .failure(TestError.boom)
        let store = MockNotificationFetchTimestampStore()
        let sut = FetchNotificationsUseCase(notificationService: service, timestampStore: store)

        do {
            _ = try await sut.execute(forceRefresh: true)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
        XCTAssertNil(store.lastFetchedAt, "Timestamp should not be stamped on failure")
    }
}
