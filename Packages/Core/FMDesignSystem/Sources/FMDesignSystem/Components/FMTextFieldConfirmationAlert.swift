import SwiftUI

/// Centered confirmation dialog that embeds a single text field between the
/// message and the action buttons — for destructive actions that require
/// re-entering a value (e.g. a password) before proceeding.
/// Sibling to `FMConfirmationAlert`, which has no slot for embedded content.
public struct FMTextFieldConfirmationAlert: View {
    let title: String
    let message: String
    let textFieldLabel: String
    @Binding var text: String
    let isSecureTextField: Bool
    let errorMessage: String?
    let primaryButtonTitle: String
    let primaryButtonColor: Color
    let secondaryButtonTitle: String?
    let isLoading: Bool
    let isPrimaryEnabled: Bool
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?

    public init(
        title: String,
        message: String,
        textFieldLabel: String,
        text: Binding<String>,
        isSecureTextField: Bool = true,
        errorMessage: String? = nil,
        primaryButtonTitle: String,
        primaryButtonColor: Color = FMColors.error,
        secondaryButtonTitle: String? = "Cancelar",
        isLoading: Bool = false,
        isPrimaryEnabled: Bool = true,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.textFieldLabel = textFieldLabel
        self._text = text
        self.isSecureTextField = isSecureTextField
        self.errorMessage = errorMessage
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonColor = primaryButtonColor
        self.secondaryButtonTitle = secondaryButtonTitle
        self.isLoading = isLoading
        self.isPrimaryEnabled = isPrimaryEnabled
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }

    private var isPrimaryDisabled: Bool {
        !isPrimaryEnabled
            || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isLoading
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            VStack(spacing: 0) {
                // Title
                Text(title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                // Message
                Text(message)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                FMTextField(
                    label: textFieldLabel,
                    text: $text,
                    isSecure: isSecureTextField
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                // Primary button
                Button(action: onPrimaryAction) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: primaryButtonColor == FMColors.error ? FMColors.onError : FMColors.onPrimary))
                        } else {
                            Text(primaryButtonTitle)
                                .font(FMTypography.labelLarge)
                                .foregroundColor(isPrimaryDisabled ? FMColors.onSurface.opacity(0.38) : (primaryButtonColor == FMColors.error ? FMColors.onError : FMColors.onPrimary))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isPrimaryDisabled ? FMColors.onSurface.opacity(0.12) : primaryButtonColor)
                    )
                }
                .disabled(isPrimaryDisabled)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Secondary button (optional)
                if let onSecondaryAction, let secondaryTitle = secondaryButtonTitle {
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
    FMTextFieldConfirmationAlert(
        title: "¿Eliminar cuenta?",
        message: "Esta acción es permanente. Ingresa tu contraseña para continuar.",
        textFieldLabel: "Contraseña actual",
        text: .constant(""),
        primaryButtonTitle: "Eliminar",
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}
