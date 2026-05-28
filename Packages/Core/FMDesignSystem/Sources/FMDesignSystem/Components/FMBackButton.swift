import SwiftUI

/// Standard back button used across the app, placed inside a `ToolbarItem`.
///
/// On iOS 26+ it renders a plain chevron and lets the toolbar apply the native
/// Liquid Glass treatment automatically (no manually-drawn circle, so there's no
/// flat gray disc over photo/dark backgrounds). On earlier iOS it falls back to a
/// translucent `.ultraThinMaterial` circle.
public struct FMBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if #available(iOS 26.0, *) {
                // The toolbar wraps this in native Liquid Glass automatically.
                // A 44pt frame + contentShape guarantees a proper tap target
                // (the bare glyph alone is too small to hit reliably).
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            } else {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    // Larger invisible hit area around the 32pt circle.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }
}
