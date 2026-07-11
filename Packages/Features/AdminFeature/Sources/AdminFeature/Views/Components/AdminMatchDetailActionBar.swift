import SwiftUI
import FMDesignSystem

/// Floating liquid-glass action bar for the admin match detail screen.
///
/// Three circular icon buttons — edit (pencil), cancel (xmark), complete (checkmark).
/// The glass treatment mirrors `FMTabBar` (iOS 26 `.glassEffect`, `.ultraThinMaterial`
/// fallback). Button actions are intentionally wired by the caller; defaults are no-ops
/// because the action flows are delivered in a later iteration.
struct AdminMatchDetailActionBar: View {
    var onEdit: () -> Void = {}
    var onCancel: () -> Void = {}
    var onComplete: () -> Void = {}

    var body: some View {
        let content = HStack(spacing: 8) {
            actionButton(icon: "pencil", tint: FMColors.onSurface, action: onEdit)
            actionButton(icon: "xmark", tint: FMColors.error, action: onCancel)
            actionButton(icon: "checkmark", tint: FMColors.primary, action: onComplete)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .hoverEffect(.highlight)
            } else {
                content
                    .background(fallbackGlassBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Button

    private func actionButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fallback Glass (iOS < 26)

    private var fallbackGlassBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

#Preview {
    ZStack {
        FMColors.background.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                AdminMatchDetailActionBar()
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}
