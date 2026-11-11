import Foundation

extension Notification.Name {
    /// A push for an ADMIN/ORGANIZER inbox arrived. `userInfo["inbox"]` holds the raw inbox.
    public static let operationalNotificationPushReceived = Notification.Name("operationalNotificationPushReceived")
}

/// The two operational notification inboxes. PLAYER stays in PlayerFeature.
public enum OperationalInbox: String, CaseIterable, Sendable {
    case admin = "ADMIN"
    case organizer = "ORGANIZER"

    /// `nil` for PLAYER, a missing value or anything unknown (the contract treats
    /// those as the player inbox).
    public init?(raw: String?) {
        guard let raw, let inbox = OperationalInbox(rawValue: raw.uppercased()) else { return nil }
        self = inbox
    }
}

public struct OperationalNotification: Identifiable, Equatable, Sendable {
    public static let paymentWindowWarningType = "MATCH_PAYMENT_WINDOW_WARNING"

    public let id: String
    public let title: String
    public let body: String
    public let type: String
    public let createdAt: Date
    public let isRead: Bool
    public let matchId: String?

    public init(id: String, title: String, body: String, type: String, createdAt: Date, isRead: Bool, matchId: String?) {
        self.id = id
        self.title = title
        self.body = body
        self.type = type
        self.createdAt = createdAt
        self.isRead = isRead
        self.matchId = matchId
    }

    public var isPaymentWindowWarning: Bool { type == Self.paymentWindowWarningType }
}
