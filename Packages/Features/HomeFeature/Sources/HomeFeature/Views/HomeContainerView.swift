import SwiftUI
import CoreData
import FMDesignSystem
import SharedModels
import UIKit

/// Main Home View with Tab Navigation
public struct HomeContainerView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var userSession: UserSession
    @State private var selectedTab: HomeTab = .home
    @State private var navigationPath = NavigationPath()   // custom tab bar (iOS <26)
    @State private var homeNavPath = NavigationPath()      // iOS 26 home tab
    @State private var matchesNavPath = NavigationPath()   // iOS 26 matches tab
    @State private var reservedNavPath = NavigationPath()  // iOS 26 reserved tab
    @StateObject private var matchesViewModel = MatchesViewModel(
        fetchMatchesUseCase: HomeDependencyFactory().makeFetchMatchesUseCase()
    )
    @StateObject private var reservedViewModel = ReservedMatchesViewModel(
        fetchMyMatchesUseCase: HomeDependencyFactory().makeFetchMyMatchesUseCase()
    )
    @StateObject private var homeViewModel = HomeViewModel()

    /// Callback for logout action
    public var onLogout: (() -> Void)?
    
    public init(onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
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
        .task {
            matchesViewModel.setCache(MatchCoreDataCacheRepository(context: context))
            reservedViewModel.setCache(MatchCoreDataCacheRepository(context: context, entityName: "CachedReservedMatchEntity"))
            await matchesViewModel.loadMatches()
            await reservedViewModel.load()
            await homeViewModel.load()
        }
    }
    
    // MARK: - Native TabView (iOS 26+ with Liquid Glass & Loupe)
    
    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.home, systemImage: "house", value: .home) {
                NavigationStack(path: $homeNavPath) {
                    HomeContentView(selectedTab: $selectedTab, navigationPath: $homeNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match)
                        }
                }
            }

            Tab(L10n.Tab.matches, image: "soccerBall", value: .matches) {
                NavigationStack(path: $matchesNavPath) {
                    MatchesListView(navigationPath: $matchesNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match)
                        }
                }
            }

            Tab(L10n.Tab.reserved, systemImage: "calendar", value: .reserved) {
                NavigationStack(path: $reservedNavPath) {
                    ReservedView(navigationPath: $reservedNavPath)
                        .navigationBarHidden(true)
                        .navigationDestination(for: MatchItem.self) { match in
                            MatchDetailView(match: match)
                        }
                }
            }

            Tab(value: HomeTab.profile, role: nil) {
                NavigationStack {
                    ProfileView(onLogout: onLogout)
                }
            } label: {
                Label {
                    Text(L10n.Tab.profile)
                } icon: {
                    if let icon = profileTabIcon() {
                        Image(uiImage: icon)
                            .renderingMode(.original)
                    } else {
                        Image(userSession.currentUser?.gender.defaultAvatarAssetName ?? "defaultAvatar", bundle: .main)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 24, height: 24)
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
                    MatchDetailView(match: match)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeContentView(selectedTab: $selectedTab, navigationPath: $navigationPath)
            case .matches:
                MatchesListView(navigationPath: $navigationPath)
            case .reserved:
                ReservedView(navigationPath: $navigationPath)
            case .profile:
                ProfileView(onLogout: onLogout)
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
                    profileDefaultImageName: userSession.currentUser?.gender.defaultAvatarAssetName
                )
                .id(profileImageUrl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                #if DEBUG
                .onAppear {
                    print("[FMDEBUG] homeViewModel.profileImageUrl: \(String(homeViewModel.profileImageUrl ?? ""))")
                    print("[FMDEBUG] userSession.currentUser?.profilePicURL: \(String(describing: userSession.currentUser?.profilePicURL?.absoluteString))")
                    print("[FMDEBUG] profileImageUrl usado en TabBar: \(String(describing: profileImageUrl))")
                }
                #endif
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingDetail)
    }

    // MARK: - Profile Tab Icon

    /// Renders the default avatar asset into a 24×24 circular UIImage
    /// so the Liquid Glass tab bar shows it at the correct size.
    @available(iOS 26.0, *)
    private func profileTabIcon() -> UIImage? {
        let assetName = userSession.currentUser?.gender.defaultAvatarAssetName ?? "defaultAvatar"
        guard let original = UIImage(named: assetName) else { return nil }
        let size = CGSize(width: 24, height: 24)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            original.draw(in: rect)
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
    
    /// Rasterizes any UIImage into a 28×28 circular icon (alwaysOriginal)
    private func makeCircularIcon(from image: UIImage) -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            image.draw(in: rect)
        }.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - Preview
#Preview {
    HomeContainerView()
}

