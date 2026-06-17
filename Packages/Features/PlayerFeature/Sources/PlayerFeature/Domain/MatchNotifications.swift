import Foundation

extension Notification.Name {
    /// Posted when the current user joins, leaves, or cancels a match.
    /// ViewModels observing match lists should reload when received.
    static let matchMembershipDidChange = Notification.Name("matchMembershipDidChange")

    /// Posted when a regional data-only push (`type=matches_updated`) arrives,
    /// signalling that the public matches feed for a region changed on the
    /// backend. `MatchesViewModel` re-runs the V2 fetch with its current
    /// `sinceVersion` so the list auto-refreshes. `userInfo` carries the
    /// optional `"region"` (`String`) and `"version"` (`Int64`) from the payload.
    static let matchesRegionDidUpdate = Notification.Name("matchesRegionDidUpdate")
}

// MARK: - Match Push Router

/// Bridges raw FCM/APNs payloads into the in-app notification used to refresh
/// the matches feed. Lives here (public) so the app target's `AppDelegate` can
/// forward `didReceiveRemoteNotification` without knowing the feature internals.
public enum MatchPushRouter {

    /// Inspects a remote-notification payload and, if it is a regional
    /// `matches_updated` data push, posts `.matchesRegionDidUpdate`.
    ///
    /// - Returns: `true` if the payload was a recognized matches push (so the
    ///   caller can report `.newData` to the system), `false` otherwise.
    @discardableResult
    public static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String, type == "matches_updated" else {
            return false
        }
        let region = userInfo["region"] as? String
        // APNs/FCM data values arrive as strings; tolerate a numeric value too.
        let version = (userInfo["version"] as? String).flatMap { Int64($0) }
            ?? (userInfo["version"] as? NSNumber)?.int64Value

        var info: [String: Any] = [:]
        if let region { info["region"] = region }
        if let version { info["version"] = version }

        NotificationCenter.default.post(
            name: .matchesRegionDidUpdate,
            object: nil,
            userInfo: info
        )
        return true
    }
}
