import Foundation

extension Notification.Name {
    /// Posted when a remote push arrives that isn't a recognized `matches_updated`
    /// data push. The backend doesn't tag these with a distinguishing `type`, so
    /// any such push is treated as a signal that a new in-app notification was
    /// created server-side. `NotificationsViewModel` re-fetches when received.
    static let inAppNotificationsPushReceived = Notification.Name("inAppNotificationsPushReceived")
}

// MARK: - In-App Notification Push Router

/// Bridges raw FCM/APNs payloads into the in-app notification used to refresh
/// the notifications feed. Lives here (public) so the app target's `AppDelegate`
/// can forward `didReceiveRemoteNotification` without knowing feature internals.
public enum InAppNotificationPushRouter {

    /// Posts `.inAppNotificationsPushReceived`. Call this for any remote push
    /// that `MatchPushRouter` didn't already recognize as a matches-feed push.
    @discardableResult
    public static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        NotificationCenter.default.post(name: .inAppNotificationsPushReceived, object: nil)
        return true
    }
}
