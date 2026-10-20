import SwiftUI
import FMDesignSystem

// MARK: - Identity

struct ProfileIdentity {
    let name: String
    let avatarURL: URL?
    let defaultAvatarAssetName: String
}

/// What the top bar's `leading` / `trailing` content needs to follow the collapse.
struct ProfileBarContext {
    let progress: CGFloat
    /// White over the pitch image, the theme's content colour once the bar is plain.
    let foreground: Color
}

// MARK: - Preference keys

private struct ProfileAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [ProfileAnchor: CGRect] = [:]

    static func reduce(value: inout [ProfileAnchor: CGRect], nextValue: () -> [ProfileAnchor: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct ProfileScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private let profileCoordinateSpace = "profile"

private extension View {
    func profileAnchor(_ anchor: ProfileAnchor) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ProfileAnchorPreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named(profileCoordinateSpace))]
                )
            }
        }
    }
}

// MARK: - Backdrop

/// Pitch photo behind the header. The fades and the dark layer live here rather than
/// in the image so they follow light/dark mode and the collapse progress.
struct ProfileHeaderBackdrop: View {
    let collapseProgress: CGFloat

    static let height: CGFloat = 400

    var body: some View {
        let background = FMColors.background

        ZStack {
            // The image fills a flexible clear view instead of sizing the layout itself:
            // a scaled-to-fill image is wider than the screen and would widen the
            // whole profile with it.
            Color.clear
                .overlay(
                    Image("ProfileHeaderPitch", bundle: .main)
                        .resizable()
                        .scaledToFill()
                )
                .clipped()
                .opacity(1 - collapseProgress)

            Color.black
                .opacity(0.22 * (1 - collapseProgress))

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.38),
                    .init(color: background.opacity(0.10), location: 0.55),
                    .init(color: background.opacity(0.45), location: 0.72),
                    .init(color: background.opacity(0.85), location: 0.88),
                    .init(color: background, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: Self.height)
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Identity overlay

/// The one visible avatar + name while the header collapses. The copies in the content
/// and in the bar are invisible anchors, so nothing is ever drawn twice.
private struct ProfileIdentityOverlay: View {
    let identity: ProfileIdentity
    let model: ProfileCollapseModel

    var body: some View {
        if let avatarFrame = model.avatarFrame,
           let nameFrame = model.nameFrame,
           let nameStart = model.frames[.nameStart] {
            ZStack(alignment: .topLeading) {
                FMAvatar(
                    url: identity.avatarURL,
                    defaultImageName: identity.defaultAvatarAssetName,
                    size: avatarFrame.width,
                    showCameraBadge: false
                )
                .overlay(
                    Circle().stroke(FMColors.outlineVariant.opacity(1 - model.progress), lineWidth: 2)
                )
                .position(x: avatarFrame.midX, y: avatarFrame.midY)

                // Drawn at the expanded size and scaled, so the type size changes
                // continuously instead of jumping between two fonts.
                Text(identity.name)
                    .font(ProfileHeaderMetrics.expandedNameFont)
                    .foregroundColor(FMColors.onBackground)
                    .lineLimit(1)
                    .frame(width: nameStart.width, height: nameStart.height)
                    .scaleEffect(nameFrame.height / max(nameStart.height, 1))
                    .position(x: nameFrame.midX, y: nameFrame.midY)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }
}

enum ProfileHeaderMetrics {
    static let avatarSize: CGFloat = 132
    static let avatarHeaderHeight: CGFloat = 180
    static let collapsedAvatarSize: CGFloat = 32
    static let barHeight: CGFloat = 56
    static let expandedNameFont = FMTypography.headlineSmall
    static let collapsedNameFont = FMTypography.titleMedium
    /// Progress after which the bar switches from white to the theme's content colour.
    static let barColorSwitch: CGFloat = 0.65
}

// MARK: - Scaffold

/// Shared layout of "Mi perfil" and "Perfil de jugador": pitch backdrop, large avatar
/// and name, scrolling content, and a bar that the avatar and name collapse into.
struct ProfileScaffold<Leading: View, Trailing: View, Meta: View, Content: View>: View {
    let identity: ProfileIdentity
    /// Title shown centered in the bar and faded out as the identity arrives (player profile).
    var barTitle: String?
    /// Space the collapsed identity leaves for leading bar content that doesn't overlap it.
    var leadingInset: CGFloat = 0
    var trailingReserve: CGFloat = 16
    /// Dark gradient behind the bar so brand and icons stay readable over the photo.
    var showsBarScrim = false
    var bottomPadding: CGFloat = 40
    var onAvatarTap: (() -> Void)?
    let onRefresh: () async -> Void
    let leading: (ProfileBarContext) -> Leading
    let trailing: (ProfileBarContext) -> Trailing
    let meta: Meta
    let content: Content

    @State private var liveFrames: [ProfileAnchor: CGRect] = [:]
    @State private var scrollTopBaseline: CGFloat?
    @State private var scrollTop: CGFloat = 0

    init(
        identity: ProfileIdentity,
        barTitle: String? = nil,
        leadingInset: CGFloat = 0,
        trailingReserve: CGFloat = 16,
        showsBarScrim: Bool = false,
        bottomPadding: CGFloat = 40,
        onAvatarTap: (() -> Void)? = nil,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder leading: @escaping (ProfileBarContext) -> Leading,
        @ViewBuilder trailing: @escaping (ProfileBarContext) -> Trailing,
        @ViewBuilder meta: () -> Meta,
        @ViewBuilder content: () -> Content
    ) {
        self.identity = identity
        self.barTitle = barTitle
        self.leadingInset = leadingInset
        self.trailingReserve = trailingReserve
        self.showsBarScrim = showsBarScrim
        self.bottomPadding = bottomPadding
        self.onAvatarTap = onAvatarTap
        self.onRefresh = onRefresh
        self.leading = leading
        self.trailing = trailing
        self.meta = meta()
        self.content = content()
    }

    // MARK: Model

    private var scrollOffset: CGFloat {
        guard let baseline = scrollTopBaseline else { return 0 }
        return baseline - scrollTop
    }

    /// Start anchors scroll with the content, so they are measured live and converted
    /// back to where they sit at offset 0; end anchors live in the fixed bar.
    private var model: ProfileCollapseModel {
        var frames = liveFrames
        for anchor in [ProfileAnchor.avatarStart, .nameStart] {
            if var frame = frames[anchor] {
                frame.origin.y += scrollOffset
                frames[anchor] = frame
            }
        }
        return ProfileCollapseModel(frames: frames, scrollOffset: scrollOffset)
    }

    // MARK: Body

    var body: some View {
        GeometryReader { outer in
            let safeTop = outer.safeAreaInsets.top
            let viewport = outer.size.height + safeTop
            let model = model

            ZStack(alignment: .top) {
                FMColors.background

                ProfileHeaderBackdrop(collapseProgress: model.progress)

                scrollView(model: model, safeTop: safeTop, viewport: viewport)

                // Plain bar surface that fades in as the identity arrives, so content
                // scrolling underneath never shows through the name and the status bar.
                FMColors.background
                    .frame(height: safeTop + ProfileHeaderMetrics.barHeight)
                    .opacity(model.progress)
                    .allowsHitTesting(false)

                if showsBarScrim {
                    barScrim(progress: model.progress, safeTop: safeTop)
                }

                topBar(model: model, safeTop: safeTop)

                if model.isReady {
                    ProfileIdentityOverlay(identity: identity, model: model)
                }
            }
            .coordinateSpace(name: profileCoordinateSpace)
            .ignoresSafeArea(edges: .top)
            .onPreferenceChange(ProfileAnchorPreferenceKey.self) { liveFrames = $0 }
            .onPreferenceChange(ProfileScrollTopPreferenceKey.self) { top in
                guard let top else { return }
                if scrollTopBaseline == nil { scrollTopBaseline = top }
                scrollTop = top
            }
        }
    }

    // MARK: Scroll content

    private func scrollView(model: ProfileCollapseModel, safeTop: CGFloat, viewport: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ProfileScrollTopPreferenceKey.self,
                        value: proxy.frame(in: .named(profileCoordinateSpace)).minY
                    )
                }
                .frame(height: 0)

                Color.clear.frame(height: safeTop + ProfileHeaderMetrics.barHeight)

                avatarAnchor(isReady: model.isReady)
                    .frame(height: ProfileHeaderMetrics.avatarHeaderHeight)

                Text(identity.name)
                    .font(ProfileHeaderMetrics.expandedNameFont)
                    .foregroundColor(FMColors.onBackground)
                    .lineLimit(1)
                    .opacity(model.isReady ? 0 : 1)
                    .profileAnchor(.nameStart)
                    .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    meta
                    content
                }
                .padding(.top, 12)
                .padding(.bottom, bottomPadding)
            }
            // A short profile couldn't otherwise scroll far enough to finish the collapse:
            // the content is always at least a viewport plus the identity's travel tall.
            .frame(minHeight: viewport + model.travel, alignment: .top)
        }
        .refreshable {
            // Unstructured so releasing the gesture doesn't cancel the request mid-flight.
            await Task { await onRefresh() }.value
        }
    }

    private func avatarAnchor(isReady: Bool) -> some View {
        ZStack {
            if !isReady {
                FMAvatar(
                    url: identity.avatarURL,
                    defaultImageName: identity.defaultAvatarAssetName,
                    size: ProfileHeaderMetrics.avatarSize
                )
            }
            Color.clear
                .frame(width: ProfileHeaderMetrics.avatarSize, height: ProfileHeaderMetrics.avatarSize)
                .contentShape(Circle())
                .onTapGesture { onAvatarTap?() }
                .profileAnchor(.avatarStart)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Top bar

    private func barScrim(progress: CGFloat, safeTop: CGFloat) -> some View {
        LinearGradient(
            colors: [.black.opacity(0.68), .black.opacity(0.38), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: safeTop + ProfileHeaderMetrics.barHeight + 24)
        .opacity(progress < 1 ? 1 - progress : 0)
        .allowsHitTesting(false)
    }

    private func topBar(model: ProfileCollapseModel, safeTop: CGFloat) -> some View {
        let progress = model.progress
        let context = ProfileBarContext(
            progress: progress,
            foreground: progress >= ProfileHeaderMetrics.barColorSwitch ? FMColors.onSurface : .white
        )
        let titleFade = min(max(progress / 0.4, 0), 1)

        return ZStack {
            // Invisible: only here so the identity knows where to land.
            HStack(spacing: 10) {
                Color.clear
                    .frame(
                        width: ProfileHeaderMetrics.collapsedAvatarSize,
                        height: ProfileHeaderMetrics.collapsedAvatarSize
                    )
                    .profileAnchor(.avatarEnd)

                Text(identity.name)
                    .font(ProfileHeaderMetrics.collapsedNameFont)
                    .lineLimit(1)
                    .opacity(0)
                    .profileAnchor(.nameEnd)

                Spacer(minLength: 0)
            }
            .padding(.leading, 16 + leadingInset)
            .padding(.trailing, trailingReserve)
            .accessibilityHidden(true)

            if let barTitle {
                Text(barTitle)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(context.foreground)
                    .opacity(1 - titleFade)
                    .offset(y: -ProfileHeaderMetrics.barHeight * 0.2 * titleFade)
            }

            HStack(spacing: 0) {
                leading(context)
                Spacer(minLength: 0)
                trailing(context)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: ProfileHeaderMetrics.barHeight)
        .padding(.top, safeTop)
        .animation(.easeInOut(duration: 0.2), value: context.foreground)
    }
}
