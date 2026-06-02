import Foundation

// MARK: - List Response

struct NotificationListResponse: Decodable {
    let data: [NotificationDTO]
}

// MARK: - Delete Response

struct DeleteNotificationResponse: Decodable {
    let data: Bool
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

struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let notificationType: NotificationType
    let createdAt: Date
    let metadata: NotificationMetadata?
    let isRead: Bool

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: createdAt)
    }
}

// MARK: - Notification Type

enum NotificationType: String {
    case paymentFailed      = "PAYMENT_FAILED"
    case reservationExpired = "RESERVATION_EXPIRED"
    case matchCanceled      = "MATCH_CANCELED"
    case unknown

    var iconName: String {
        switch self {
        case .reservationExpired: return "calendar.badge.exclamationmark"
        case .matchCanceled:      return "calendar.badge.minus"
        case .paymentFailed:      return "creditcard.trianglebadge.exclamationmark"
        case .unknown:            return "bell.fill"
        }
    }
}

// MARK: - Metadata

struct NotificationMetadata: Decodable {
    let matchId: String?
    let fieldName: String?
    let type: String?
    let refundStatus: String?
}
