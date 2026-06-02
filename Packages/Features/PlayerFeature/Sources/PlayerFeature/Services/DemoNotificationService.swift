import Foundation

// MARK: - DemoNotificationService

/// Mock de notificaciones para modo demo.
/// No realiza llamadas de red — devuelve datos profesionales prefabricados.
final class DemoNotificationService: NotificationServiceProtocol {

    func fetchNotifications() async throws -> [NotificationItem] {
        Self.mockItems
    }

    /// En demo, el borrado es no-op (no hay estado persistido).
    func deleteNotification(id: String) async throws {}
}

// MARK: - Mock Data

extension DemoNotificationService {

    /// Un matchId fijo de demo para que la navegación a MatchDetail funcione con DemoMatchService.
    private static let demoMatchId = "demo-match-001"

    static let mockItems: [NotificationItem] = {
        let now = Date()
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }
        func daysAgo(_ d: Double) -> Date  { now.addingTimeInterval(-d * 86400) }

        let meta = NotificationMetadata(
            matchId: demoMatchId,
            fieldName: "Cancha Central",
            type: nil,
            refundStatus: nil
        )
        let metaCanceled = NotificationMetadata(
            matchId: demoMatchId,
            fieldName: "Cancha San José",
            type: nil,
            refundStatus: "REFUNDED"
        )

        return [
            NotificationItem(
                id: "demo-notif-1",
                title: "Reservación expirada",
                body: "Tu reservación para el partido en Cancha Central ha expirado.",
                notificationType: .reservationExpired,
                createdAt: hoursAgo(0.03),   // ~2 min ago
                metadata: meta,
                isRead: false
            ),
            NotificationItem(
                id: "demo-notif-2",
                title: "Reservación expirada",
                body: "Tu reservación para el partido en Cancha El Centro ha expirado.",
                notificationType: .reservationExpired,
                createdAt: hoursAgo(0.58),   // ~35 min ago
                metadata: NotificationMetadata(matchId: demoMatchId, fieldName: "Cancha El Centro", type: nil, refundStatus: nil),
                isRead: false
            ),
            NotificationItem(
                id: "demo-notif-3",
                title: "Partido cancelado",
                body: "Tu partido ha sido cancelado por el organizador. Se ha iniciado el reembolso de tu pago en Cancha San José.",
                notificationType: .matchCanceled,
                createdAt: daysAgo(1).addingTimeInterval(-3600),
                metadata: metaCanceled,
                isRead: true
            ),
            NotificationItem(
                id: "demo-notif-4",
                title: "Pago fallido",
                body: "Tu pago para el partido falló. Has sido eliminado del partido.",
                notificationType: .paymentFailed,
                createdAt: daysAgo(1).addingTimeInterval(-10800),
                metadata: NotificationMetadata(matchId: demoMatchId, fieldName: nil, type: nil, refundStatus: nil),
                isRead: true
            ),
            NotificationItem(
                id: "demo-notif-5",
                title: "Partido cancelado",
                body: "Tu partido en Cancha Norte ha sido cancelado. No se realizó ningún cobro a tu cuenta.",
                notificationType: .matchCanceled,
                createdAt: daysAgo(5),
                metadata: NotificationMetadata(matchId: demoMatchId, fieldName: "Cancha Norte", type: nil, refundStatus: "NO_CHARGE"),
                isRead: true
            )
        ]
    }()
}
