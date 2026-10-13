import SwiftUI

/// Replica of the system back button, for the two screens that can't use the real one.
///
/// **Do not reach for this when adding a screen.** The app's back affordance is iOS's own
/// button: push the screen and leave it alone — no `.navigationBarBackButtonHidden(true)`,
/// no toolbar item, no `.edgeSwipeToGoBack`. That is what keeps every back button
/// identical, and the system's rendering (material, shadow, dark mode, edge swipe) is not
/// reproducible by hand — every attempt at redrawing it here came out visibly wrong.
///
/// Only two screens genuinely can't use it, and they are the only callers:
/// - `MatchDetailView` hides the navigation bar outright so the hero image isn't clipped,
///   so there's no bar to hold a back button.
/// - `OnboardingContainerView`'s back moves between onboarding steps rather than popping
///   the navigation stack, so the native button would do the wrong thing.
///
/// `isStandalone: true` marks the first case — floated over content via `.overlay`, with
/// no toolbar around it. The rendering is the same; the flag exists so that case can be
/// tuned without touching the other.
public struct FMBackButton: View {
    private let action: () -> Void
    private let isStandalone: Bool

    private let circleSize: CGFloat = 40
    private let hitAreaSize: CGFloat = 44

    public init(action: @escaping () -> Void, isStandalone: Bool = false) {
        self.action = action
        self.isStandalone = isStandalone
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: circleSize, height: circleSize)
                .background(
                    Circle()
                        .fill(FMColors.surfaceContainerLowest)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 1)
                )
                // Larger invisible hit area around the circle.
                .frame(width: hitAreaSize, height: hitAreaSize)
                .contentShape(Circle())
        }
        // Without `.plain`, the toolbar and the app accent colour retint the glyph.
        .buttonStyle(.plain)
    }
}
