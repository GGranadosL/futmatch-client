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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 48)

                Image(context.imageName, bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .accessibilityHidden(true)

                Text(context.title)
                    .font(FMTypography.titleLarge)
                    .bold()
                    .foregroundColor(FMColors.onBackground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text(context.message)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                FMPrimaryButton(title: L10n.Guest.signIn) {
                    requestSignIn()
                }
                .padding(.top, 28)

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
                    .padding(.top, 12)
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(FMColors.background.ignoresSafeArea())
    }
}

#Preview {
    GuestSignInPromptView(context: .home, secondaryTitle: "Browse matches", onSecondary: {})
}
