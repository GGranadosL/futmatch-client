import XCTest
import AdminFeature
@testable import PlayerFeature

final class InAppNotificationPushRouterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InAppNotificationPushRouter.clearPendingRoutes()
    }

    func test_inboxValue_readsTopLevelKey() {
        XCTAssertEqual(InAppNotificationPushRouter.inboxValue(from: ["inbox": "ADMIN"]), "ADMIN")
    }

    func test_inboxValue_fallsBackToMetadataJSON() {
        let userInfo: [AnyHashable: Any] = ["metadata": #"{"matchId":"m1","inbox":"ORGANIZER"}"#]
        XCTAssertEqual(InAppNotificationPushRouter.inboxValue(from: userInfo), "ORGANIZER")
    }

    func test_missingInbox_isTreatedAsPlayer() {
        XCTAssertNil(OperationalInbox(raw: InAppNotificationPushRouter.inboxValue(from: ["matchId": "m1"])))
        XCTAssertNil(OperationalInbox(raw: "PLAYER"))
    }

    func test_tapOnAdminPush_storesOperationalRoute_notPlayerMatch() {
        let handled = InAppNotificationPushRouter.handleNotificationTap([
            "gcm.message_id": "tap-\(UUID().uuidString)",
            "inbox": "admin",
            "matchId": "m1",
            "type": "MATCH_PAYMENT_WINDOW_WARNING"
        ])

        XCTAssertTrue(handled)
        XCTAssertEqual(
            InAppNotificationPushRouter.consumePendingOperationalRoute(),
            OperationalPushRoute(inbox: .admin, matchId: "m1")
        )
        XCTAssertNil(InAppNotificationPushRouter.consumePendingMatchId())
        XCTAssertNil(InAppNotificationPushRouter.consumePendingOperationalRoute(), "Consumed only once")
    }

    func test_sameTapDeliveredTwice_isHandledOnce() {
        let userInfo: [AnyHashable: Any] = ["gcm.message_id": "tap-\(UUID().uuidString)", "inbox": "ORGANIZER"]

        XCTAssertTrue(InAppNotificationPushRouter.handleNotificationTap(userInfo))
        _ = InAppNotificationPushRouter.consumePendingOperationalRoute()
        XCTAssertFalse(InAppNotificationPushRouter.handleNotificationTap(userInfo))
        XCTAssertNil(InAppNotificationPushRouter.consumePendingOperationalRoute())
    }

    func test_playerTap_keepsPlayerBehaviour() {
        let handled = InAppNotificationPushRouter.handleNotificationTap([
            "gcm.message_id": "tap-\(UUID().uuidString)",
            "matchId": "m2"
        ])

        XCTAssertTrue(handled)
        XCTAssertEqual(InAppNotificationPushRouter.consumePendingMatchId(), "m2")
        XCTAssertNil(InAppNotificationPushRouter.consumePendingOperationalRoute())
    }

    func test_clearPendingRoutes_dropsBothKinds() {
        InAppNotificationPushRouter.handleNotificationTap(["gcm.message_id": "tap-\(UUID().uuidString)", "matchId": "m3"])
        InAppNotificationPushRouter.handleNotificationTap(["gcm.message_id": "tap-\(UUID().uuidString)", "inbox": "ADMIN"])

        InAppNotificationPushRouter.clearPendingRoutes()

        XCTAssertNil(InAppNotificationPushRouter.consumePendingMatchId())
        XCTAssertNil(InAppNotificationPushRouter.consumePendingOperationalRoute())
    }

    // MARK: - Shared match links

    func test_matchLink_keepsMatchPendingOnce_andPostsOpenSignal() throws {
        let id = "123e4567-e89b-12d3-a456-426614174000"
        let url = try XCTUnwrap(URL(string: "https://interfut.app/matches/\(id)"))
        let opened = expectation(forNotification: .systemNotificationOpenedMatch, object: nil) { note in
            note.userInfo?["matchId"] as? String == id
        }

        XCTAssertTrue(InAppNotificationPushRouter.handleIncomingMatchLink(url))

        wait(for: [opened], timeout: 1)
        XCTAssertEqual(InAppNotificationPushRouter.consumePendingMatchId(), id)
        XCTAssertNil(InAppNotificationPushRouter.consumePendingMatchId())
    }

    func test_newerMatchLink_replacesPendingOne() throws {
        let first = "123e4567-e89b-12d3-a456-426614174000"
        let second = "223e4567-e89b-12d3-a456-426614174000"
        InAppNotificationPushRouter.handleIncomingMatchLink(try XCTUnwrap(URL(string: "https://interfut.app/matches/\(first)")))
        InAppNotificationPushRouter.handleIncomingMatchLink(try XCTUnwrap(URL(string: "https://interfut.app/matches/\(second)")))

        XCTAssertEqual(InAppNotificationPushRouter.consumePendingMatchId(), second)
    }

    func test_invalidLink_isIgnored() throws {
        let url = try XCTUnwrap(URL(string: "https://evil.com/matches/123e4567-e89b-12d3-a456-426614174000"))

        XCTAssertFalse(InAppNotificationPushRouter.handleIncomingMatchLink(url))
        XCTAssertNil(InAppNotificationPushRouter.consumePendingMatchId())
    }

    func test_operationalPushReceived_postsOperationalSignal_notPlayerBadge() {
        let operational = expectation(forNotification: .operationalNotificationPushReceived, object: nil) { note in
            note.userInfo?["inbox"] as? String == "ADMIN"
        }
        let player = expectation(forNotification: .inAppNotificationsPushReceived, object: nil)
        player.isInverted = true

        InAppNotificationPushRouter.handleRemoteNotification([
            "gcm.message_id": "msg-\(UUID().uuidString)",
            "inbox": "ADMIN"
        ])

        wait(for: [operational, player], timeout: 0.3)
    }
}
