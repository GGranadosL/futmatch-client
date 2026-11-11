import FMDesignSystem
import SwiftUI

/// Round share button floated over the match hero, styled like `FMBackButton`
/// so the two read as a pair. Opens the system share sheet with `message`.
struct MatchShareButton: View {
    let message: String

    private let circleSize: CGFloat = 40
    private let hitAreaSize: CGFloat = 44

    var body: some View {
        ShareLink(item: message) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                // The glyph's arrow sits high; nudge it so it looks centred in the circle.
                .offset(y: -1)
                .frame(width: circleSize, height: circleSize)
                .background(
                    Circle()
                        .fill(FMColors.surfaceContainerLowest)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 1)
                )
                .frame(width: hitAreaSize, height: hitAreaSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.MatchDetail.shareAccessibility)
    }
}
