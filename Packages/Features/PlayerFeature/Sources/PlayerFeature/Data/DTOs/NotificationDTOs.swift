import Foundation

// MARK: - List Response

struct NotificationListResponse: Decodable {
    let data: [NotificationDTO]
}

// MARK: - Delete Response

struct DeleteNotificationResponse: Decodable {
    let data: Bool
}

// MARK: - Unread Count Response

struct UnreadCountResponse: Decodable {
    struct Payload: Decodable {
        let unreadCount: Int
    }
    let data: Payload
}

// MARK: - Mark All Read Response

struct MarkAllReadResponse: Decodable {
    struct Payload: Decodable {
        /// May be 0 — still a success: there was just nothing left to mark.
        let markedAsReadCount: Int
    }
    let data: Payload
}

// MARK: - DTO

struct NotificationDTO: Decodable {
    let id: String
    let userId: String?
    let title: String
    let body: String
    let notificationType: String
    let createdAt: Int64
    let metadata: String
    let isRead: Bool

    func toNotificationItem() -> NotificationItem {
        let date = Date(timeIntervalSince1970: Double(createdAt) / 1000)
        let parsedMetadata = (metadata.data(using: .utf8))
            .flatMap { try? JSONDecoder().decode(NotificationMetadata.self, from: $0) }
        return NotificationItem(
            id: id,
            title: title,
            body: body,
            notificationType: NotificationType(rawValue: notificationType) ?? .unknown,
            createdAt: date,
            metadata: parsedMetadata,
            isRead: isRead
        )
    }
}

// MARK: - Domain Model

struct NotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let body: String
    let notificationType: NotificationType
    let createdAt: Date
    let metadata: NotificationMetadata?
    var isRead: Bool

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: createdAt)
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case paymentSucceeded       = "PAYMENT_SUCCEEDED"
    case paymentFailed          = "PAYMENT_FAILED"
    case reservationExpired     = "RESERVATION_EXPIRED"
    case matchCanceled          = "MATCH_CANCELED"
    case matchCompletedWinner   = "MATCH_COMPLETED_WINNER"
    case matchCompletedWinnerMvp = "MATCH_COMPLETED_WINNER_MVP"
    case matchCompletedLoser    = "MATCH_COMPLETED_LOSER"
    case matchCompletedDraw     = "MATCH_COMPLETED_DRAW"
    case unknown

    var iconName: String {
        switch self {
        case .paymentSucceeded:       return "checkmark.circle"
        case .reservationExpired:     return "calendar.badge.exclamationmark"
        case .matchCanceled:          return "calendar.badge.minus"
        case .paymentFailed:          return "creditcard.trianglebadge.exclamationmark"
        case .matchCompletedWinner:   return "trophy"
        case .matchCompletedWinnerMvp: return "star.circle"
        case .matchCompletedLoser:    return "flag.checkered"
        case .matchCompletedDraw:     return "equal.circle"
        case .unknown:                return "bell.fill"
        }
    }

    /// Whether the icon should read as a problem (red) rather than neutral news.
    var isAlert: Bool {
        switch self {
        case .paymentFailed, .reservationExpired, .matchCanceled: return true
        default: return false
        }
    }
}

// MARK: - Metadata

struct NotificationMetadata: Codable, Equatable {
    let matchId: String?
    let fieldName: String?
    let type: String?
    let refundStatus: String?
}
