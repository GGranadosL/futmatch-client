import SwiftUI
import FMDesignSystem

/// Multi-layer decorative background for `AuthLandingView`, ported from the Android
/// auth landing screen. Four layers, back to front:
///
/// 1. Vertical base gradient — avoids a flat fill.
/// 2. Hero halo — separates the Lottie/brand from the rest.
/// 3. Bottom halo — adds depth behind the action buttons.
/// 4. Side vignette — softly darkens the screen edges.
///
/// Pure gradients (no real-time blur), sits behind content, never captures gestures,
/// and adapts to light/dark through `FMColors`.
struct AuthLandingBackground: View {
    private let background = FMColors.background
    private let surface = FMColors.surface
    private let primary = FMColors.primary
    private let secondary = FMColors.secondary

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: background, location: 0),
                        .init(color: surface.opacity(0.94), location: 0.48),
                        .init(color: background, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    stops: [
                        .init(color: primary.opacity(0.18), location: 0),
                        .init(color: primary.opacity(0.06), location: 0.48),
                        .init(color: .clear, location: 1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.78
                )
                .frame(width: width * 1.56, height: width * 1.56)
                .position(x: width * 0.5, y: height * 0.22)

                RadialGradient(
                    colors: [secondary.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.72
                )
                .frame(width: width * 1.44, height: width * 1.44)
                .position(x: width * 0.5, y: height * 0.82)

                LinearGradient(
                    stops: [
                        .init(color: background.opacity(0.42), location: 0),
                        .init(color: .clear, location: 0.20),
                        .init(color: .clear, location: 0.80),
                        .init(color: background.opacity(0.42), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .frame(width: width, height: height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
