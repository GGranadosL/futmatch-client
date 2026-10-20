import XCTest
@testable import PlayerFeature

final class UserDefaultsNotificationCacheStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "NotificationCacheStoreTests")!
        defaults.removePersistentDomain(forName: "NotificationCacheStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "NotificationCacheStoreTests")
        super.tearDown()
    }

    func test_snapshot_survivesANewStoreInstance() {
        let first = UserDefaultsNotificationCacheStore(defaults: defaults)
        let fetchedAt = Date(timeIntervalSince1970: 1_234)
        first.replaceNotifications([.stub(id: "a", metadata: NotificationMetadata(matchId: "m1", fieldName: nil, type: nil, refundStatus: nil))], fetchedAt: fetchedAt)
        first.setUnreadCount(3)

        let second = UserDefaultsNotificationCacheStore(defaults: defaults)

        XCTAssertEqual(second.notifications.map(\.id), ["a"])
        XCTAssertEqual(second.notifications.first?.metadata?.matchId, "m1")
        XCTAssertEqual(second.unreadCount, 3)
        XCTAssertEqual(second.lastFetchedAt, fetchedAt)
    }

    func test_markAllRead_flagsItemsAndZeroesCounter() {
        let store = UserDefaultsNotificationCacheStore(defaults: defaults)
        store.replaceNotifications([.stub(id: "a", isRead: false)], fetchedAt: Date())
        store.setUnreadCount(1)

        store.markAllRead()

        XCTAssertEqual(store.notifications.map(\.isRead), [true])
        XCTAssertEqual(store.unreadCount, 0)
    }

    func test_clear_removesEverythingIncludingLegacyKeys() {
        defaults.set(["old"], forKey: "notifications.seenIds")
        defaults.set(5, forKey: "notifications.seenUnreadCount")
        defaults.set(1.0, forKey: "notification.lastFetchedAt")
        let store = UserDefaultsNotificationCacheStore(defaults: defaults)
        store.replaceNotifications([.stub()], fetchedAt: Date())
        store.setUnreadCount(2)

        store.clear()

        XCTAssertTrue(store.notifications.isEmpty)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertNil(store.lastFetchedAt)
        XCTAssertNil(defaults.object(forKey: "notifications.seenIds"))
        XCTAssertNil(defaults.object(forKey: "notifications.seenUnreadCount"))
        XCTAssertNil(defaults.object(forKey: "notification.lastFetchedAt"))
    }

    func test_setUnreadCount_neverGoesNegative() {
        let store = UserDefaultsNotificationCacheStore(defaults: defaults)
        store.setUnreadCount(-4)
        XCTAssertEqual(store.unreadCount, 0)
    }
}
