import SwiftUI
import CoreData
import AdminFeature
import FMDesignSystem
import SharedModels
import UIKit

/// Main Home View with Tab Navigation
public struct HomeContainerView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var userSession: UserSession
    @State private var selectedTab: HomeTab = .home
    @State private var navigationPath = NavigationPath()   // custom tab bar (iOS <26)
    @State private var homeNavPath = NavigationPath()      // iOS 26 home tab
    @State private var matchesNavPath = NavigationPath()   // iOS 26 matches tab
    @State private var reservedNavPath = NavigationPath()  // iOS 26 reserved tab
    @State private var profileNavPath = NavigationPath()   // iOS 26 profile tab
    /// Cached circular profile image for the Liquid Glass tab icon (iOS 26+).
    @State private var profileTabImage: UIImage? = nil
    /// Prerasterized default avatar used as placeholder while the real photo loads.
    @State private var defaultProfileTabImage: UIImage? = nil
    @StateObject private var matchesViewModel: MatchesViewModel
    @StateObject private var reservedViewModel: ReservedMatchesViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var notificationsViewModel: NotificationsViewModel
    /// ADMIN/ORGANIZER unread counters. Rebuilt with this view on logout, so counters
    /// never carry over to another account.
    @StateObject private var operationalStore: OperationalNotificationsStore
    /// A tapped admin/organizer push waiting for the user's role to be known.
    @State private var pendingOperationalRoute: OperationalPushRoute?
    /// Bumped to close the screens Home pushed with flags (admin panel, notifications…)
    /// before a push opens a hub.
    @State private var homeResetToken = 0
    /// Shown when a notification or shared link points to a match we can't load
    /// (deleted, not visible to this user, or offline).
    @State private var showOpenMatchError = false

    /// Callback for logout action
    public var onLogout: (() -> Void)?
    /// Callback fired after the account was successfully deleted, once the local session must be torn down.
    public var onAccountDeleted: (() -> Void)?
    private let isDemoMode: Bool
    /// Builds a fresh ranking screen state for every push from Home's Ranking card.
    private let makeRankingViewModel: @MainActor (RankingRoute) -> RankingViewModel
    /// `false` while browsing as a guest: only the Matches tab is open; Home,
    /// Reserved and Profile invite the user to sign in.
    private let isAuthenticated: Bool

    public init(
        onLogout: (() -> Void)? = nil,
        onAccountDeleted: (() -> Void)? = nil,
        isDemoMode: Bool = false,
        isAuthenticated: Bool = true,
        countryRepository: any CountryRepositoryProtocol = FallbackCountryRepository(),
        managedObjectContext: NSManagedObjectContext? = nil
    ) {
        self.onLogout = onLogout
        self.onAccountDeleted = onAccountDeleted
        self.isDemoMode = isDemoMode
        self.isAuthenticated = isAuthenticated
        let factory = PlayerDependencyFactory(isDemoMode: isDemoMode, countryRepository: countryRepository)
        let cacheRepo: MatchCoreDataCacheRepository?
        let reservedCacheRepo: MatchCoreDataCacheRepository?
        if let ctx = managedObjectContext {
            cacheRepo = MatchCoreDataCacheRepository(context: ctx)
            reservedCacheRepo = MatchCoreDataCacheRepository(context: ctx, entityClass: CachedReservedMatchEntity.self)
        } else {
            cacheRepo = nil
            reservedCacheRepo = nil
        }
        _matchesViewModel = StateObject(wrappedValue: MatchesViewModel(
            fetchMatchesUseCase: factory.makeFetchMatchesUseCase(),
            fetchCurrentLocationUseCase: factory.makeFetchCurrentLocationUseCase(),
            cacheRepo: cacheRepo
        ))
        _reservedViewModel = StateObject(wrappedValue: ReservedMatchesViewModel(
            fetchMyMatchesUseCase: factory.makeFetchMyMatchesUseCase(),
            fetchCurrentLocationUseCase: factory.makeFetchCurrentLocationUseCase(),
            cacheRepo: reservedCacheRepo
        ))
        _homeViewModel = StateObject(wrappedValue: factory.makeHomeViewModel())
        _notificationsViewModel = StateObject(wrappedValue: factory.makeNotificationsViewModel())
        _operationalStore = StateObject(wrappedValue: AdminDependencyFactory().makeOperationalNotificationsStore())
        makeRankingViewModel = { route in
            factory.makeRankingViewModel(season: route.season, communityId: route.communityId)
        }
    }
    
    /// Whether a detail screen is being shown (hides custom tab bar)
    private var isShowingDetail: Bool {
        !navigationPath.isEmpty
    }
    
    public var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                nativeTabView
            } else {
                customTabView
            }
        }
        .environmentObject(matchesViewModel)
        .environmentObject(reservedViewModel)
        .environmentObject(homeViewModel)
        .environmentObject(notificationsViewModel)
        .environment(\.operationalNotificationsStore, operationalStore)
        .environment(\.isAuthenticated, isAuthenticated)
        // Keyed by the session: signing in from the guest sheet keeps this view (and
        // whatever screen the user was on) and runs the account loads right away.
        .task(id: isAuthenticated) {
            guard isAuthenticated else { return }
            async let home: Void = homeViewModel.load()
            async let reserved: Void = reservedViewModel.load()
            // The badge is requested once per session; after that pushes bump it locally
            // and pull-to-refresh on the notifications screen reconciles it.
            async let badge: Void = notificationsViewModel.loadUnreadCountForSession()
            // Fire-and-forget: pays Stripe's one-time framework binding cost now,
            // in parallel with the network loads above, instead of on first entry
            // into Settings or the payment flow.
            Task.detached(priority: .utility) { PaymentSDKWarmup.prewarm() }
            _ = await (home, reserved, badge)
        }
        // The role arrives with the cached/fetched profile, possibly after the first task.
        .task(id: operationalInbox) {
            guard isAuthenticated, let inbox = operationalInbox else { return }
            await operationalStore.refresh(inbox)
            processPendingOperationalRoute()
        }
        .onChange(of: isAuthenticated) { signedIn in
            // The guest feed has no players; swap it for the full one.
            guard signedIn else { return }
            Task { await matchesViewModel.reload() }
        }
        // Prerasterize the default avatar placeholder at the same size as the real
        // photo so the tab icon never jumps in size when the download completes.
        // Keyed by gender: re-renders when the cached profile finishes loading,
        // so a female user gets her avatar instead of the initial male fallback.
        .task(id: userSession.currentUser?.gender) {
            let assetName = userSession.currentUser?.gender?.defaultAvatarAssetName ?? "defaultAvatar"
            if let raw = UIImage(named: assetName) {
                defaultProfileTabImage = makeCircularIcon(from: raw, size: 30)
            }
        }
        // Re-download whenever the URL changes from either source.
        // `.task(id:)` cancels + restarts when `effectiveProfileImageUrl` changes,
        // including the nil → URL transition after `homeViewModel.load()` completes.
        .task(id: effectiveProfileImageUrl) {
            await loadProfileTabImage()
        }
        .fmToast(L10n.MatchDetail.openLinkError, isPresented: $showOpenMatchError, style: .error)
        .onReceive(NotificationCenter.default.publisher(for: .systemNotificationOpenedMatch)) { note in
            guard let matchId = note.userInfo?["matchId"] as? String else { return }
            _ = InAppNotificationPushRouter.consumePendingMatchId()
            openMatchFromSystemNotification(matchId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .systemNotificationOpenedOperationalInbox)) { _ in
            guard let route = InAppNotificationPushRouter.consumePendingOperationalRoute() else { return }
            pendingOperationalRoute = route
            processPendingOperationalRoute()
        }
        .task {
            // Launched by tapping a notification: the tap fired before this view existed.
            if let matchId = InAppNotificationPushRouter.consumePendingMatchId() {
                openMatchFromSystemNotification(matchId)
            }
            if let route = InAppNotificationPushRouter.consumePendingOperationalRoute() {
                pendingOperationalRoute = route
                processPendingOperationalRoute()
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, isAuthenticated else { return }
            Task {
                async let home: Void = homeViewModel.load()
                async let reserved: Void = reservedViewModel.load()
                async let operational: Void = refreshOperationalCount()
                _ = await (home, reserved, operational)
            }
        }
    }

    // MARK: - Operational inboxes

    /// The operational inbox this user's role reads, if any. An admin doesn't get the
    /// ORGANIZER inbox implicitly.
    private var operationalInbox: OperationalInbox? {
        guard AdminRemoteConfig().isAdminFeatureEnabled else { return nil }
        switch userSession.currentUser?.userRole {
        case .administrator: return .admin
        case .organizer: return .organizer
        default: return nil
        }
    }

    private func refreshOperationalCount() async {
        guard let inbox = operationalInbox else { return }
        await operationalStore.refresh(inbox)
    }

    /// Opens the hub a tapped admin/organizer push asked for, once the session and the
    /// role are known. A route for an inbox the current role can't read is dropped;
    /// the server checks it again anyway.
    private func processPendingOperationalRoute() {
        guard let route = pendingOperationalRoute, isAuthenticated else { return }
        guard let role = userSession.currentUser?.userRole else { return } // wait for the profile
        pendingOperationalRoute = nil
        let allowed = (route.inbox == .admin && role == .administrator)
            || (route.inbox == .organizer && role == .organizer)
        guard allowed, AdminRemoteConfig().isAdminFeatureEnabled else { return }

        Task { await operationalStore.refresh(route.inbox) }
        selectedTab = .home
        homeResetToken += 1
        let destination = OperationalInboxRoute(inbox: route.inbox)
        // Replacing the path (instead of appending) means a second tap never stacks
        // a second hub.
        if #available(iOS 26.0, *) {
            homeNavPath = NavigationPath()
        } else {
            navigationPath = NavigationPath()
        }
        Task { @MainActor in
            // Let the pops finish before pushing, or the push can be swallowed.
            try? await Task.sleep(nanoseconds: 350_000_000)
            if #available(iOS 26.0, *) {
                homeNavPath.append(destination)
            } else {
                navigationPath.append(destination)
            }
        }
    }
    
    /// Opens the match a tapped system notification or a shared link points to, on the Home tab.
    private func openMatchFromSystemNotification(_ matchId: String) {
        Task {
            guard let match = await notificationsViewModel.match(forId: matchId) else {
                showOpenMatchError = true
                return
            }
            selectedTab = .home
            if #available(iOS 26.0, *) {
                homeNavPath.append(match)
            } else {
                navigationPath.append(match)
            }
        }
    }

    // MARK: - Native TabView (iOS 26+ with Liquid Glass & Loupe)
    
    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.home, systemImage: "house", value: .home) {
                NavigationStack(path: $homeNavPath) {
                    homeTabRoot(navigationPath: $homeNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode)
                        }
                        .navigationDestination(for: RankingRoute.self) { route in
                            RankingView(viewModel: makeRankingViewModel(route))
                        }
                        .navigationDestination(for: OperationalInboxRoute.self) { route in
                            OperationalNotificationsHubView(inbox: route.inbox, store: operationalStore)
                        }
                }
            }

            Tab(value: HomeTab.matches, role: nil) {
                NavigationStack(path: $matchesNavPath) {
                    MatchesListView(navigationPath: $matchesNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode)
                        }
                }
            } label: {
                Label {
                    Text(L10n.Tab.matches)
                } icon: {
                    // Custom assets fill their bounds (no built-in padding like SF Symbols),
                    // so they need a larger frame to match the SF Symbol visual weight.
                    Image("soccerBall", bundle: .main)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
            }

            Tab(L10n.Tab.reserved, systemImage: "calendar", value: .reserved) {
                NavigationStack(path: $reservedNavPath) {
                    reservedTabRoot(navigationPath: $reservedNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode, source: .booked)
                        }
                }
            }

            Tab(value: HomeTab.profile, role: nil) {
                NavigationStack(path: $profileNavPath) {
                    profileTabRoot(navigationPath: $profileNavPath)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode)
                        }
                }
            } label: {
                Label {
                    Text(L10n.Tab.profile)
                } icon: {
                    // Both branches render a prerasterized 30×30 UIImage so the tab
                    // icon never changes size when the real photo finishes loading.
                    let displayIcon = profileTabImage ?? defaultProfileTabImage
                    if let icon = displayIcon {
                        Image(uiImage: icon)
                            .renderingMode(.original)
                    } else {
                        // Fallback before defaultProfileTabImage is ready (first frame only).
                        Image(userSession.currentUser?.gender?.defaultAvatarAssetName ?? "defaultAvatar", bundle: .main)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .tint(FMColors.primary)
    }
    
    // MARK: - Custom TabView (iOS < 26 fallback)
    
    private var customTabView: some View {
        NavigationStack(path: $navigationPath) {
            tabContent
                .navigationDestination(for: MatchItem.self) { match in
                    MatchDetailView(match: match, isDemoMode: isDemoMode, source: selectedTab == .reserved ? .booked : .nearby)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .navigationDestination(for: RankingRoute.self) { route in
                    RankingView(viewModel: makeRankingViewModel(route))
                }
                .navigationDestination(for: OperationalInboxRoute.self) { route in
                    OperationalNotificationsHubView(inbox: route.inbox, store: operationalStore)
                }
        }
    }
    
    @State private var tabBarHeight: CGFloat = FMTabBar.contentBottomInset

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .home:
                homeTabRoot(navigationPath: $navigationPath)
            case .matches:
                MatchesListView(navigationPath: $navigationPath)
            case .reserved:
                reservedTabRoot(navigationPath: $navigationPath)
            case .profile:
                profileTabRoot(navigationPath: $navigationPath)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        // Reserving the space here, rather than padding each screen by hand, is the whole
        // fix: SwiftUI adds this on top of the existing bottom safe area, so the home
        // indicator can't be counted twice — which is what left a hole under the last row.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(
                height: isShowingDetail ? 0 : tabBarHeight + FMTabBar.contentBreathingSpace
            )
        }
        .overlay(alignment: .bottom) {
            if !isShowingDetail {
                let profileImageUrl = homeViewModel.profileImageUrl ?? userSession.currentUser?.profilePicURL?.absoluteString
                FMTabBar(
                    selectedTab: $selectedTab,
                    profileImageUrl: profileImageUrl,
                    profileDefaultImageName: userSession.currentUser?.gender?.defaultAvatarAssetName
                )
                .id(profileImageUrl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TabBarHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            }
        }
        // The bar floats in an overlay and reserves no space, so its measured height is
        // handed to the tab screens to pad their scroll content by.
        .onPreferenceChange(TabBarHeightPreferenceKey.self) { height in
            if height > 0 { tabBarHeight = height }
        }

        .animation(.easeInOut(duration: 0.25), value: isShowingDetail)
    }

    // MARK: - Tab Roots (guest-aware)

    @ViewBuilder
    private func homeTabRoot(navigationPath: Binding<NavigationPath>) -> some View {
        if isAuthenticated {
            HomeContentView(
                selectedTab: $selectedTab,
                navigationPath: navigationPath,
                isDemoMode: isDemoMode,
                resetToken: homeResetToken
            )
        } else {
            GuestSignInPromptView(
                context: .home,
                secondaryTitle: L10n.Guest.browseMatches,
                onSecondary: { selectedTab = .matches }
            )
        }
    }

    @ViewBuilder
    private func reservedTabRoot(navigationPath: Binding<NavigationPath>) -> some View {
        if isAuthenticated {
            ReservedView(navigationPath: navigationPath)
        } else {
            GuestSignInPromptView(context: .reserved)
        }
    }

    @ViewBuilder
    private func profileTabRoot(navigationPath: Binding<NavigationPath>) -> some View {
        if isAuthenticated {
            ProfileView(onLogout: onLogout, onAccountDeleted: onAccountDeleted, selectedTab: $selectedTab, navigationPath: navigationPath)
        } else {
            GuestSignInPromptView(context: .profile)
        }
    }

    // MARK: - Profile Tab Icon

    /// Single source of truth for the user's profile picture URL.
    /// Prefers the freshly loaded `HomeViewModel` value, falling back to the
    /// cached `UserSession` value.
    private var effectiveProfileImageUrl: String? {
        homeViewModel.profileImageUrl
            ?? userSession.currentUser?.profilePicURL?.absoluteString
    }

    /// Downloads the user's profile photo and stores it as a circular UIImage
    /// for the Liquid Glass tab icon. Falls back silently — the label's `else`
    /// branch shows the bundled default avatar if this returns without setting
    /// `profileTabImage`.
    private func loadProfileTabImage() async {
        guard let urlString = effectiveProfileImageUrl else {
            profileTabImage = nil
            return
        }
        // Routed through the shared loader (memory → disk → network, deduped)
        // so this doesn't re-download a photo ProfileView/FMTabBar already have.
        guard let downloaded = await FMImageLoader.shared.load(urlString) else { return }
        // 30pt matches the visual weight of SF Symbols in the iOS 26 tab bar
        // (which have built-in padding). `UIScreen.main.scale` keeps the bitmap
        // retina (e.g. 90px on @3x) so the photo stays sharp.
        profileTabImage = makeCircularIcon(from: downloaded, size: 30)
    }

    /// Rasterizes a UIImage into a circular icon of the given size (alwaysOriginal).
    private func makeCircularIcon(from image: UIImage, size: CGFloat = 28) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: targetSize)
            UIBezierPath(ovalIn: rect).addClip()
            image.draw(in: rect)
        }.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - Preview
#Preview {
    HomeContainerView()
}

/// Navigation value for an operational inbox hub opened from a push.
struct OperationalInboxRoute: Hashable {
    let inbox: OperationalInbox
}
