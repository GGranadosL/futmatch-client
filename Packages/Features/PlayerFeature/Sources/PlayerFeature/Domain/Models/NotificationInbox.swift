import Foundation

/// What the notifications screen and the bell badge show at a given moment.
struct NotificationInbox: Equatable {
    var items: [NotificationItem]
    var unreadCount: Int
}
