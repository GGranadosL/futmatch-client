import SwiftUI

/// Standard back button used across the app, placed inside a `ToolbarItem`.
///
/// On iOS 26+ it renders a plain chevron and lets the toolbar apply the native
/// Liquid Glass treatment automatically — the system adapts the glass to the bar's
/// own chrome, which a hand-drawn `.glassEffect` can't reproduce (tried it: on plain
/// content it shows up as a boxy capsule with a visible outline). On earlier iOS it
/// falls back to a translucent `.ultraThinMaterial` circle.
///
/// Set `isStandalone: true` only when there's no real toolbar to wrap it — e.g.
/// floated over a full-bleed hero image via `.overlay`. That's the one case a
/// hand-drawn Liquid Glass capsule is unavoidable, since there's no bar for the
/// system to blend it into.
public struct FMBackButton: View {
    private let action: () -> Void
    private let isStandalone: Bool

    public init(action: @escaping () -> Void, isStandalone: Bool = false) {
        self.action = action
        self.isStandalone = isStandalone
    }

    public var body: some View {
        Button(action: action) {
            if #available(iOS 26.0, *) {
                if isStandalone {
                    // The 64pt-wide capsule reads as more surrounding whitespace than
                    // the 44pt square toolbar frame, so the same point size looks
                    // smaller here — bumped to 24 to match the toolbar chevron visually.
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 64, height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .contentShape(Capsule())
                } else {
                    // The toolbar wraps this in native Liquid Glass automatically.
                    // A 44pt frame + contentShape guarantees a proper tap target
                    // (the bare glyph alone is too small to hit reliably).
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            } else {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    // Larger invisible hit area around the 36pt circle.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }
}
