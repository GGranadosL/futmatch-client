import SwiftUI
import FMDesignSystem

/// Status capsule shared by the admin match card and the dashboard row.
/// `scheduled` has no badge: it is the default state and adds only noise.
struct AdminMatchStatusBadge: View {
    let status: AdminMatchStatus

    /// Whether this status is worth flagging on a card.
    static func isVisible(for status: AdminMatchStatus) -> Bool {
        status != .scheduled
    }

    var body: some View {
        if Self.isVisible(for: status) {
            Text(status.displayName)
                .font(FMTypography.labelSmall)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(color.opacity(0.12)))
        }
    }

    private var color: Color {
        switch status {
        case .completed, .inProgress: return FMColors.primary
        case .pendingResult:          return FMColors.tertiary
        case .canceled:               return FMColors.error
        case .scheduled:              return FMColors.onSurfaceVariant
        }
    }
}
