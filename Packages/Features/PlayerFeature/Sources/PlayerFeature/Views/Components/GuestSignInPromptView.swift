import SwiftUI
import FMDesignSystem

/// Full-screen invitation to sign in, shown on account-based tabs (Home,
/// Reserved, Profile) while browsing as a guest.
struct GuestSignInPromptView: View {
    /// Which tab the prompt stands in for — picks the illustration and copy.
    enum Context {
        case home, reserved, profile

        /// Placeholder art lives in the app's asset catalog under these names;
        /// swap the files to change the illustration, no code change needed.
        var imageName: String {
            switch self {
            case .home: return "guestHome"
            case .reserved: return "guestReserved"
            case .profile: return "guestProfile"
            }
        }

        var title: String {
            switch self {
            case .home: return L10n.Guest.homeTitle
            case .reserved: return L10n.Guest.reservedTitle
            case .profile: return L10n.Guest.profileTitle
            }
        }

        var message: String {
            switch self {
            case .home: return L10n.Guest.homeMessage
            case .reserved: return L10n.Guest.reservedMessage
            case .profile: return L10n.Guest.profileMessage
            }
        }
    }

    let context: Context
    /// Secondary action under the sign-in button (Home: "Browse matches"). Hidden when nil.
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    @Environment(\.requestSignIn) private var requestSignIn

    /// Illustration canvas is 390×440 (see docs/illustrations); its bottom edge
    /// fades into the screen background, so it sits flush against the copy.
    private static let illustrationAspect: CGFloat = 390.0 / 440.0
    /// Caps the hero on wide screens (iPad) so the copy stays above the fold.
    private static let maxIllustrationHeight: CGFloat = 480

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(proxy.size.width / Self.illustrationAspect, Self.maxIllustrationHeight)
            ScrollView {
                VStack(spacing: 0) {
                    // Full-bleed hero that runs under the status bar.
                    Image(context.imageName, bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: heroHeight, alignment: .bottom)
                        .clipped()
                        .accessibilityHidden(true)

                    copyAndActions
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .frame(maxWidth: 480)
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(.container, edges: .top)
            .scrollBounceBehaviorBasedOnSizeIfAvailable()
        }
        .background(FMColors.background.ignoresSafeArea())
    }

    private var copyAndActions: some View {
        VStack(spacing: 0) {
            Text(context.title)
                .font(FMTypography.titleLarge)
                .bold()
                .foregroundColor(FMColors.onBackground)
                .multilineTextAlignment(.center)

            Text(context.message)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            FMPrimaryButton(title: L10n.Guest.signIn) {
                requestSignIn()
            }
            .padding(.top, 24)

            if let secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    HStack(spacing: 6) {
                        Text(secondaryTitle)
                        Image(systemName: "arrow.right")
                    }
                    .font(FMTypography.button)
                    .foregroundColor(FMColors.onBackground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .padding(.top, 8)
            }
        }
    }
}

private extension View {
    /// Content that fits doesn't rubber-band (iOS 16.4+); older systems keep the default.
    @ViewBuilder
    func scrollBounceBehaviorBasedOnSizeIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

#Preview {
    GuestSignInPromptView(context: .home, secondaryTitle: "Browse matches", onSecondary: {})
}
