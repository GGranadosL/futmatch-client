import SwiftUI

/// Generic empty-state card: a centered icon, a message, and an optional action link.
/// Used across Home for "no next match", "no suggested matches", and "no last match".
public struct FMEmptyStateCard: View {
    let icon: String
    let message: String
    var actionLabel: String?
    var onActionTap: (() -> Void)?
    /// When true the card grows to fill all the space its parent offers,
    /// for screens where the empty state is the whole content.
    var fillsAvailableSpace: Bool

    public init(
        icon: String,
        message: String,
        actionLabel: String? = nil,
        onActionTap: (() -> Void)? = nil,
        fillsAvailableSpace: Bool = false
    ) {
        self.icon = icon
        self.message = message
        self.actionLabel = actionLabel
        self.onActionTap = onActionTap
        self.fillsAvailableSpace = fillsAvailableSpace
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(FMColors.onSurfaceVariant)

            Text(message)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            if let actionLabel {
                Button {
                    onActionTap?()
                } label: {
                    Text(actionLabel)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: fillsAvailableSpace ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("With action") {
    FMEmptyStateCard(
        icon: "calendar",
        message: "Sin próximo partido",
        actionLabel: "Unirme a un partido"
    )
    .padding()
}

#Preview("Without action") {
    FMEmptyStateCard(
        icon: "soccerball",
        message: "Sin partidos sugeridos"
    )
    .padding()
}
