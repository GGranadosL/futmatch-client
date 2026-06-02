import Foundation

extension Notification.Name {
    /// Posted when the current user joins, leaves, or cancels a match.
    /// ViewModels observing match lists should reload when received.
    static let matchMembershipDidChange = Notification.Name("matchMembershipDidChange")
}
