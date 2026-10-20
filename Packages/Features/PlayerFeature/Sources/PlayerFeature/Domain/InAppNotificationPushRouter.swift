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
}

// MARK: - In-App Notification Push Router

/// Bridges raw FCM/APNs payloads into the in-app notification used to refresh
/// the notifications feed. Lives here (public) so the app target's `AppDelegate`
/// can forward `didReceiveRemoteNotification` without knowing feature internals.
public enum InAppNotificationPushRouter {

    private static let lock = NSLock()
    private static var recentMessageIds: [String] = []
    private static var pendingMatchId: String?

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

    /// Returns and clears the match a tap asked for, if nobody handled it live.
    static func consumePendingMatchId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        defer { pendingMatchId = nil }
        return pendingMatchId
    }

    static func matchId(from userInfo: [AnyHashable: Any]) -> String? {
        if let id = userInfo["matchId"] as? String, !id.isEmpty { return id }
        guard let raw = userInfo["metadata"] as? String,
              let data = raw.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(NotificationMetadata.self, from: data),
              let id = metadata.matchId, !id.isEmpty else { return nil }
        return id
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
