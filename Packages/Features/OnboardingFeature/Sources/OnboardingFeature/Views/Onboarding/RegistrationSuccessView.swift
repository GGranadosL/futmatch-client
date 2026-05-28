import SwiftUI
import Lottie
import FMDesignSystem

/// Full-screen success screen shown after the user completes email verification.
/// Plays `success.json` (light) or `success_dark.json` (dark) from the module
/// bundle. When the user taps "Empezar a jugar", uploads any profile picture
/// to the `/user/profile-pic` endpoint, then calls the completion handler.
struct RegistrationSuccessView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isUploading = false

    /// Called when the user taps the CTA button and image upload is complete.
    /// The caller is responsible for dismissing this view and transitioning to the home screen.
    let onContinue: () -> Void

    private var animationName: String {
        colorScheme == .dark ? "success_dark" : "success"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: Lottie animation
            LottieView(animation: .named(animationName, bundle: .module))
                .playing(loopMode: .playOnce)
                .resizable()
                .frame(width: 260, height: 260)

            // MARK: Copy
            VStack(spacing: 12) {
                Text(L10n.RegistrationSuccess.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.RegistrationSuccess.subtitle)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)

            Spacer()

            // MARK: CTA
            FMPrimaryButton(
                title: L10n.RegistrationSuccess.cta,
                isLoading: isUploading,
                isEnabled: !isUploading
            ) {
                isUploading = true
                Task {
                    // Upload profile picture if one was selected (non-blocking — errors are logged but don't block navigation)
                    await viewModel.uploadProfilePictureIfNeeded()
                    isUploading = false
                    onContinue()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(FMColors.background)
        }
        .background(FMColors.background.ignoresSafeArea())
        // Hide the navigation bar — this is a terminal screen
        .navigationBarHidden(true)
    }
}

// MARK: - Preview

#Preview("Light") {
    RegistrationSuccessView(
        viewModel: OnboardingViewModel(),
        onContinue: {}
    )
}

#Preview("Dark") {
    RegistrationSuccessView(
        viewModel: OnboardingViewModel(),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
