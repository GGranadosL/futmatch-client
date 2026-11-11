import AdminFeature
import Foundation
import OSLog

extension Notification.Name {
    /// Posted when a remote push arrives that isn't a recognized `matches_updated`
    /// data push. The backend doesn't tag these with a distinguishing `type`, so
    /// any such push is treated as a signal that a new in-app notification was
    /// created server-side. `NotificationsViewModel` re-fetches when received.
    static let inAppNotificationsPushReceived = Notification.Name("inAppNotificationsPushReceived")

    /// Posted when the user taps a system notification that carries a `matchId`.
    /// `userInfo["matchId"]` holds the id.
    static let systemNotificationOpenedMatch = Notification.Name("systemNotificationOpenedMatch")

    /// Posted when the user taps a push for the ADMIN or ORGANIZER inbox. The route is
    /// read with `InAppNotificationPushRouter.consumePendingOperationalRoute()`.
    static let systemNotificationOpenedOperationalInbox = Notification.Name("systemNotificationOpenedOperationalInbox")
}

/// Where a tapped admin/organizer push should take the user: that inbox's hub.
struct OperationalPushRoute: Equatable {
    let inbox: OperationalInbox
    let matchId: String?
}

// MARK: - In-App Notification Push Router

/// Bridges raw FCM/APNs payloads into the in-app notification used to refresh
/// the notifications feed. Lives here (public) so the app target's `AppDelegate`
/// can forward `didReceiveRemoteNotification` without knowing feature internals.
public enum InAppNotificationPushRouter {

    private static let lock = NSLock()
    private static var recentMessageIds: [String] = []
    private static var pendingMatchId: String?
    private static var pendingOperationalRoute: OperationalPushRoute?
    private static var recentTapIds: [String] = []

    /// Posts `.inAppNotificationsPushReceived`. Call this for any remote push
    /// that `MatchPushRouter` didn't already recognize as a matches-feed push.
    ///
    /// The same push can reach the app twice (willPresent and didReceiveRemoteNotification),
    /// so repeated FCM message ids are ignored — otherwise the local badge would double count.
    @discardableResult
    public static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "Push")
        if let messageId = userInfo["gcm.message_id"] as? String, !registerIfNew(messageId) {
            logger.debug("InAppNotificationPushRouter: duplicate push \(messageId, privacy: .public), ignored")
            return false
        }
        // Admin/organizer pushes carry `inbox`; a missing value means PLAYER.
        if let inbox = OperationalInbox(raw: inboxValue(from: userInfo)) {
            logger.debug("InAppNotificationPushRouter: \(inbox.rawValue, privacy: .public) inbox push")
            NotificationCenter.default.post(
                name: .operationalNotificationPushReceived,
                object: nil,
                userInfo: ["inbox": inbox.rawValue]
            )
            return true
        }
        logger.debug("InAppNotificationPushRouter: unrecognized push type, posting inAppNotificationsPushReceived")
        NotificationCenter.default.post(name: .inAppNotificationsPushReceived, object: nil)
        return true
    }

    /// Call when the user taps a system notification. Reads the match to open from the
    /// payload (`matchId`, or the JSON `metadata` string) and posts
    /// `.systemNotificationOpenedMatch`. The id is also kept for a UI that isn't built
    /// yet (cold launch from the tap) — see `consumePendingMatchId()`.
    @discardableResult
    public static func handleNotificationTap(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let messageId = userInfo["gcm.message_id"] as? String, !registerTapIfNew(messageId) {
            return false
        }
        // Admin/organizer: open that inbox's hub once the session is ready. The hub
        // checks the role again; the payload never grants access.
        if let inbox = OperationalInbox(raw: inboxValue(from: userInfo)) {
            lock.lock()
            pendingOperationalRoute = OperationalPushRoute(inbox: inbox, matchId: matchId(from: userInfo))
            lock.unlock()
            NotificationCenter.default.post(name: .systemNotificationOpenedOperationalInbox, object: nil)
            return true
        }
        guard let matchId = matchId(from: userInfo) else { return false }
        lock.lock()
        pendingMatchId = matchId
        lock.unlock()
        NotificationCenter.default.post(
            name: .systemNotificationOpenedMatch,
            object: nil,
            userInfo: ["matchId": matchId]
        )
        return true
    }

    /// Call when the app is opened from a shared match link (Universal Link). Takes the
    /// same route as a notification tap: kept as pending for a cold launch and posted as
    /// `.systemNotificationOpenedMatch` for a UI that's already up. A newer link replaces
    /// an older pending one. Opening never joins the match.
    @discardableResult
    public static func handleIncomingMatchLink(_ url: URL) -> Bool {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "MatchLink")
        guard let matchId = MatchShareLink.matchId(from: url) else {
            logger.notice("Match link rejected: \(url.absoluteString, privacy: .public)")
            return false
        }
        logger.notice("Match link received: \(matchId, privacy: .public)")
        lock.lock()
        pendingMatchId = matchId
        lock.unlock()
        NotificationCenter.default.post(
            name: .systemNotificationOpenedMatch,
            object: nil,
            userInfo: ["matchId": matchId]
        )
        return true
    }

    /// Returns and clears the match a tap asked for, if nobody handled it live.
    static func consumePendingMatchId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        defer { pendingMatchId = nil }
        return pendingMatchId
    }

    /// Returns and clears the admin/organizer route a tap asked for.
    static func consumePendingOperationalRoute() -> OperationalPushRoute? {
        lock.lock()
        defer { lock.unlock() }
        defer { pendingOperationalRoute = nil }
        return pendingOperationalRoute
    }

    /// Drops any route left by a tap (logout: it belonged to the previous session).
    public static func clearPendingRoutes() {
        lock.lock()
        defer { lock.unlock() }
        pendingMatchId = nil
        pendingOperationalRoute = nil
    }

    static func inboxValue(from userInfo: [AnyHashable: Any]) -> String? {
        if let inbox = userInfo["inbox"] as? String, !inbox.isEmpty { return inbox }
        guard let raw = userInfo["metadata"] as? String,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbox = object["inbox"] as? String, !inbox.isEmpty else { return nil }
        return inbox
    }

    static func matchId(from userInfo: [AnyHashable: Any]) -> String? {
        if let id = userInfo["matchId"] as? String, !id.isEmpty { return id }
        guard let raw = userInfo["metadata"] as? String,
              let data = raw.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(NotificationMetadata.self, from: data),
              let id = metadata.matchId, !id.isEmpty else { return nil }
        return id
    }

    private static func registerTapIfNew(_ messageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !recentTapIds.contains(messageId) else { return false }
        recentTapIds.append(messageId)
        if recentTapIds.count > 20 { recentTapIds.removeFirst() }
        return true
    }

    private static func registerIfNew(_ messageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !recentMessageIds.contains(messageId) else { return false }
        recentMessageIds.append(messageId)
        if recentMessageIds.count > 20 { recentMessageIds.removeFirst() }
        return true
    }
}
