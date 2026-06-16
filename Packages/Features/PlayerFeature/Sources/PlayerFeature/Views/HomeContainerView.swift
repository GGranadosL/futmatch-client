import SwiftUI
import CoreData
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
    /// Cached circular profile image for the Liquid Glass tab icon (iOS 26+).
    @State private var profileTabImage: UIImage? = nil
    /// Prerasterized default avatar used as placeholder while the real photo loads.
    @State private var defaultProfileTabImage: UIImage? = nil
    @StateObject private var matchesViewModel: MatchesViewModel
    @StateObject private var reservedViewModel: ReservedMatchesViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var notificationsViewModel: NotificationsViewModel

    /// Callback for logout action
    public var onLogout: (() -> Void)?
    private let isDemoMode: Bool

    public init(
        onLogout: (() -> Void)? = nil,
        isDemoMode: Bool = false,
        countryRepository: any CountryRepositoryProtocol = FallbackCountryRepository(),
        managedObjectContext: NSManagedObjectContext? = nil
    ) {
        self.onLogout = onLogout
        self.isDemoMode = isDemoMode
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
            cacheRepo: cacheRepo
        ))
        _reservedViewModel = StateObject(wrappedValue: ReservedMatchesViewModel(
            fetchMyMatchesUseCase: factory.makeFetchMyMatchesUseCase(),
            cacheRepo: reservedCacheRepo
        ))
        _homeViewModel = StateObject(wrappedValue: HomeViewModel())
        _notificationsViewModel = StateObject(wrappedValue: factory.makeNotificationsViewModel())
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
        .task {
            await homeViewModel.load()
            await reservedViewModel.load()
            // Single initial badge fetch — subsequent refreshes happen on foreground.
            await notificationsViewModel.loadUnreadCount()
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
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await notificationsViewModel.loadUnreadCount() }
        }
    }
    
    // MARK: - Native TabView (iOS 26+ with Liquid Glass & Loupe)
    
    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.home, systemImage: "house", value: .home) {
                NavigationStack(path: $homeNavPath) {
                    HomeContentView(selectedTab: $selectedTab, navigationPath: $homeNavPath, isDemoMode: isDemoMode)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode)
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
                    ReservedView(navigationPath: $reservedNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match, isDemoMode: isDemoMode)
                        }
                }
            }

            Tab(value: HomeTab.profile, role: nil) {
                NavigationStack {
                    ProfileView(onLogout: onLogout, selectedTab: $selectedTab)
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
                    MatchDetailView(match: match, isDemoMode: isDemoMode)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeContentView(selectedTab: $selectedTab, navigationPath: $navigationPath, isDemoMode: isDemoMode)
            case .matches:
                MatchesListView(navigationPath: $navigationPath)
            case .reserved:
                ReservedView(navigationPath: $navigationPath)
            case .profile:
                ProfileView(onLogout: onLogout, selectedTab: $selectedTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
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
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingDetail)
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
        guard
            let urlString = effectiveProfileImageUrl,
            let url = URL(string: urlString)
        else {
            profileTabImage = nil
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            guard let downloaded = UIImage(data: data) else {
                return
            }
            // 30pt matches the visual weight of SF Symbols in the iOS 26 tab bar
            // (which have built-in padding). `UIScreen.main.scale` keeps the bitmap
            // retina (e.g. 90px on @3x) so the photo stays sharp.
            profileTabImage = makeCircularIcon(from: downloaded, size: 30)
        } catch {}
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

