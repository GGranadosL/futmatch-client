import SwiftUI

/// Generic alert component for confirmations, errors, notifications, and messages.
/// Displays an icon, title, message, and one or two action buttons.
/// - If `onSecondaryAction` is nil, only the primary button is shown.
/// - If `onSecondaryAction` is provided, both buttons are shown.
public struct FMConfirmationAlert: View {
    let icon: String
    let iconColor: Color
    let iconBackgroundColor: Color
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryButtonColor: Color
    let secondaryButtonTitle: String?
    let isLoading: Bool
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?

    public init(
        icon: String = "info.circle.fill",
        iconColor: Color = FMColors.primary,
        iconBackgroundColor: Color = FMColors.primary.opacity(0.15),
        title: String,
        message: String,
        primaryButtonTitle: String,
        primaryButtonColor: Color = FMColors.primary,
        secondaryButtonTitle: String? = "Cancelar",
        isLoading: Bool = false,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonColor = primaryButtonColor
        self.secondaryButtonTitle = secondaryButtonTitle
        self.isLoading = isLoading
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 72, height: 72)
                    Image(systemName: icon)
                        .font(.system(size: 44))
                        .foregroundColor(iconColor)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(message)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Primary button
                Button(action: onPrimaryAction) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: primaryButtonColor == FMColors.error ? FMColors.onError : FMColors.onPrimary))
                        } else {
                            Text(primaryButtonTitle)
                                .font(FMTypography.labelLarge)
                                .foregroundColor(primaryButtonColor == FMColors.error ? FMColors.onError : FMColors.onPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(primaryButtonColor)
                    )
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Secondary button (optional)
                if let onSecondaryAction = onSecondaryAction, let secondaryTitle = secondaryButtonTitle {
                    Button(action: onSecondaryAction) {
                        Text(secondaryTitle)
                            .font(FMTypography.labelLarge)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                } else {
                    Spacer()
                        .frame(height: 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    FMConfirmationAlert(
        title: "¿Publicar Partido?",
        message: "Una vez creado, este partido será visible inmediatamente.",
        primaryButtonTitle: "Publicar Ahora",
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}
