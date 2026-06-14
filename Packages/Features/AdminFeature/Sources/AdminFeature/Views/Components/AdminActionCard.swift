import SwiftUI
import FMDesignSystem

/// Full-width tappable row for a primary admin action (e.g. "Nuevo partido").
/// Icon chip on the left, title, and a trailing chevron — styled to match the
/// app's card language (`surfaceContainerLowest` + `outlineVariant` border).
struct AdminActionCard: View {
    let icon: String
    let title: String
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FMColors.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMColors.primaryContainer)
                    )

                Text(title)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onSurface)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        AdminActionCard(icon: "soccerball", title: "Nuevo partido")
        AdminActionCard(icon: "sportscourt.fill", title: "Nueva cancha")
        AdminActionCard(icon: "mappin.and.ellipse", title: "Nueva ubicación")
    }
    .padding()
    .background(FMColors.background)
}
