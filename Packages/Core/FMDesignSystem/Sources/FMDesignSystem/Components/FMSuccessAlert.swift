import SwiftUI
import Lottie

/// Success alert component with Lottie animation.
/// Used for success messages, confirmations, or notifications with a celebratory animation.
public struct FMSuccessAlert: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var animationName: String {
        colorScheme == .dark ? "success_dark" : "success"
    }

    public init(
        title: String,
        message: String,
        buttonTitle: String = "Entendido",
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Lottie animation
                LottieView(animation: .named(animationName, bundle: .module))
                    .playing(loopMode: .playOnce)
                    .resizable()
                    .frame(width: 140, height: 140)
                    .padding(.top, 12)

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

                // Dismiss button
                Button(action: onDismiss) {
                    Text(buttonTitle)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
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
    FMSuccessAlert(
        title: "¡Éxito!",
        message: "La acción se completó correctamente.",
        buttonTitle: "Entendido",
        onDismiss: {}
    )
}
