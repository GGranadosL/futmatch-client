import CoreGraphics
import Foundation

// MARK: - ProfileAnchor

/// The four places the profile identity (avatar + name) is measured at.
/// `*Start` sit in the scrolling content, `*End` in the top bar.
enum ProfileAnchor: Hashable, CaseIterable {
    case avatarStart, avatarEnd, nameStart, nameEnd
}

// MARK: - ProfileCollapseModel

/// Pure geometry behind the profile header collapse: maps the scroll offset to a 0…1
/// progress and interpolates the avatar and name between their expanded and
/// collapsed frames.
///
/// There is no timed animation here on purpose — the scroll view already delivers a
/// continuous position (with reverse and fling), and a fixed-duration animation
/// would lag behind the content.
struct ProfileCollapseModel: Equatable {
    /// Start frames at scroll offset 0; end frames in the top bar. Same coordinate space.
    var frames: [ProfileAnchor: CGRect] = [:]
    var scrollOffset: CGFloat = 0

    /// The overlay only takes over once every anchor has been measured; until then the
    /// regular content stays visible so there is never a frame with no avatar.
    var isReady: Bool {
        ProfileAnchor.allCases.allSatisfy { frames[$0] != nil }
    }

    /// Scroll distance over which the identity travels from the content to the bar.
    var travel: CGFloat {
        guard let start = frames[.nameStart], let end = frames[.nameEnd] else { return 0 }
        return max(0, start.minY - end.minY)
    }

    var progress: CGFloat {
        guard travel > 0 else { return 0 }
        return min(max(scrollOffset / travel, 0), 1)
    }

    /// Ease-out, so the avatar gets to the bar slightly ahead of the name.
    var avatarProgress: CGFloat {
        1 - pow(1 - progress, 2)
    }

    /// Frame the avatar is drawn at, including the rubber-band shift while overscrolling.
    var avatarFrame: CGRect? {
        interpolatedFrame(from: .avatarStart, to: .avatarEnd, progress: avatarProgress)
    }

    var nameFrame: CGRect? {
        interpolatedFrame(from: .nameStart, to: .nameEnd, progress: progress)
    }

    private func interpolatedFrame(
        from start: ProfileAnchor,
        to end: ProfileAnchor,
        progress: CGFloat
    ) -> CGRect? {
        guard let startFrame = frames[start], let endFrame = frames[end] else { return nil }
        var frame = Self.interpolate(startFrame, endFrame, progress: progress)
        // Pulling down past the top moves the content, so the identity follows it.
        frame.origin.y += max(0, -scrollOffset)
        return frame
    }

    static func interpolate(_ start: CGRect, _ end: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: start.minX + (end.minX - start.minX) * progress,
            y: start.minY + (end.minY - start.minY) * progress,
            width: start.width + (end.width - start.width) * progress,
            height: start.height + (end.height - start.height) * progress
        )
    }
}
