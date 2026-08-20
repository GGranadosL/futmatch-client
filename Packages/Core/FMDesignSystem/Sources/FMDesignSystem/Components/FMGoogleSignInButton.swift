import SwiftUI

/// "Continue with Google" button.
///
/// Height, corner radius and typography match `FMPrimaryButton` so the two stack
/// cleanly on the login screen.
///
/// The mark is Google's own artwork, loaded from the app target's asset catalog
/// rather than drawn here — their sign-in branding requires the supplied "G",
/// unmodified and un-recoloured.
///
/// Both badges are the G on a filled circle, and the circle is what changes: white
/// in `google_light`, near-black in `google_dark`. Each is meant to sit flush on a
/// surface of that shade, so the variant follows the colour scheme rather than the
/// other way round.
public struct FMGoogleSignInButton: View {
    /// Google badge for light surfaces (white circle).
    public static let lightLogoAssetName = "google_light"
    /// Google badge for dark surfaces (near-black circle).
    public static let darkLogoAssetName = "google_dark"

    /// Side of the badge, in points.
    ///
    /// This sizes the *circle*, not the "G": in Google's artwork the mark is masked
    /// to a 20×20 area of a 44×44 canvas, so the letter renders at roughly 45 % of
    /// whatever goes here. 28 pt puts the G near the cap height of the label beside
    /// it and still leaves 12 pt of breathing room inside the 52 pt button.
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
                        .progressViewStyle(CircularProgressViewStyle(tint: FMColors.onSurface))
                } else {
                    logo
                        .frame(width: Self.badgeSize, height: Self.badgeSize)

                    Text(title)
                        .font(FMTypography.button)
                        .foregroundColor(FMColors.onSurface)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
            // The whole capsule is the target, not just the glyph and label.
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .disabled(!isEnabled || isLoading)
    }

    private var logoAssetName: String {
        colorScheme == .dark ? Self.darkLogoAssetName : Self.lightLogoAssetName
    }

    @ViewBuilder
    private var logo: some View {
        // Assets live in the app target's catalog, so this resolves through the
        // main bundle — the same way `LoginView` loads `logo_futmatch`.
        if let image = UIImage(named: logoAssetName) {
            // `.original` keeps Google's four brand colours; a template render
            // would tint the mark, which their guidelines disallow.
            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
        } else {
            Image(systemName: "globe")
                .resizable()
                .scaledToFit()
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMGoogleSignInButton(title: "Continuar con Google") {}
        FMGoogleSignInButton(title: "Continuar con Google", isLoading: true) {}
        FMGoogleSignInButton(title: "Continuar con Google", isEnabled: false) {}
    }
    .padding()
}
