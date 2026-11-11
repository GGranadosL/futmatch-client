import FMDesignSystem
import SwiftUI

// MARK: - Progress

/// Maps the match detail's scroll offset to how far the hero has faded, the same way
/// the profile header fades its pitch photo: driven by the scroll position itself (with
/// reverse and fling), not by a timed animation.
struct MatchDetailHeroFade {
    /// Scroll distance over which the photo fades out and the top bar fades in.
    static let distance: CGFloat = 160
    /// Progress after which the venue name starts appearing in the bar.
    static let titleStart: CGFloat = 0.6

    static func progress(forOffset offset: CGFloat) -> CGFloat {
        min(max(offset / distance, 0), 1)
    }

    static func titleOpacity(forProgress progress: CGFloat) -> CGFloat {
        min(max((progress - titleStart) / (1 - titleStart), 0), 1)
    }
}

// MARK: - Scroll state

/// Holds the scroll progress outside `MatchDetailView`'s own state, so scrolling only
/// re-renders the views that fade instead of the whole detail screen every frame.
final class MatchDetailHeroScrollState: ObservableObject {
    @Published private(set) var progress: CGFloat = 0
    private var baseline: CGFloat?

    /// `contentTop` is the top of the scroll content in the scroll view's space. The
    /// first value is the resting position; offsets are measured from it.
    func update(contentTop: CGFloat) {
        if baseline == nil { baseline = contentTop }
        let next = MatchDetailHeroFade.progress(forOffset: (baseline ?? contentTop) - contentTop)
        // Past either end the value doesn't change; skip publishing so nothing redraws.
        if next != progress { progress = next }
    }
}

struct MatchDetailScrollTopKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

let matchDetailScrollSpace = "matchDetailScroll"

// MARK: - Views

/// Fades the hero photo (and the text drawn over it) as the content scrolls up.
struct MatchDetailHeroFadeModifier: ViewModifier {
    @ObservedObject var state: MatchDetailHeroScrollState

    func body(content: Content) -> some View {
        content.opacity(1 - state.progress)
    }
}

/// Plain bar behind the floating back/share buttons. It fades in as the photo fades
/// out, so content scrolling underneath never shows through the status bar, and the
/// venue name arrives in it once the hero's own title has gone.
struct MatchDetailTopBar: View {
    @ObservedObject var state: MatchDetailHeroScrollState
    let title: String

    /// Back button: 8pt top padding + 44pt hit area, plus breathing room below.
    private let height: CGFloat = 60

    var body: some View {
        Text(title)
            .font(FMTypography.titleMedium)
            .foregroundColor(FMColors.onBackground)
            .lineLimit(1)
            // Leaves room for the round buttons on both sides.
            .padding(.horizontal, 72)
            .padding(.top, 8)
            .opacity(MatchDetailHeroFade.titleOpacity(forProgress: state.progress))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                FMColors.background
                    .opacity(state.progress)
                    .ignoresSafeArea(edges: .top)
            )
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
