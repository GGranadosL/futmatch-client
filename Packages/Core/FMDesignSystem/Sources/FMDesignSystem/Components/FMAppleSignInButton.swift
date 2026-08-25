import SwiftUI

/// "Continue with Apple" button.
///
/// Replaces `SignInWithAppleButton` on the login screen. Apple's native button
/// draws its own label in SF Pro, sized off the button's height — next to
/// `FMGoogleSignInButton` (Inter SemiBold 16) the two read as different
/// typefaces at different sizes, which is exactly what this component fixes:
/// same height, radius, badge size, spacing and font as the Google button, so
/// the pair stacks as one family.
///
/// Apple's Sign in with Apple guidelines allow a custom button as long as it
/// keeps their chrome: the unmodified Apple logo, one of the approved labels,
/// and a solid black or white fill with nothing else inside it. Colours are
/// therefore literal black/white rather than `FMColors` tokens — the button is
/// Apple's branding, not the app's theme. Per those guidelines the fill inverts
/// with the colour scheme (black on light, white on dark), matching what
/// `.signInWithAppleButtonStyle(...)` did before.
public struct FMAppleSignInButton: View {
    /// Matches `FMGoogleSignInButton.badgeSize` so both marks occupy the same
    /// slot. The glyph itself is inset inside it (see `logo`).
    private static let badgeSize: CGFloat = 28

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    public init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foreground))
                } else {
                    logo
                        .frame(width: Self.badgeSize, height: Self.badgeSize)

                    Text(title)
                        .font(FMTypography.button)
                        .foregroundColor(foreground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(fill)
            )
            // The white variant needs an edge or it disappears into a light
            // surface; the black one is already its own boundary.
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(FMColors.outlineVariant, lineWidth: colorScheme == .dark ? 0 : 1)
            )
            // The whole capsule is the target, not just the glyph and label.
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .disabled(!isEnabled || isLoading)
    }

    private var fill: Color {
        colorScheme == .dark ? .white : .black
    }

    private var foreground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var logo: some View {
        // The apple.logo symbol fills its frame edge to edge, unlike Google's
        // badge where the mark is masked to ~45 % of the artwork. Insetting it
        // here lands both glyphs at the same optical size, and the slight
        // upward nudge accounts for the leaf sitting above the apple's body.
        Image(systemName: "apple.logo")
            .resizable()
            .scaledToFit()
            .foregroundColor(foreground)
            .padding(Self.badgeSize * 0.18)
            .offset(y: -1)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMAppleSignInButton(title: "Continuar con Apple") {}
        FMAppleSignInButton(title: "Continuar con Apple", isLoading: true) {}
        FMAppleSignInButton(title: "Continuar con Apple", isEnabled: false) {}
    }
    .padding()
}
