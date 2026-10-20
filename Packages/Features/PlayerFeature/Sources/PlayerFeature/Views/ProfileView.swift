import SwiftUI
import FMDesignSystem
import SharedModels
import NetworkFramework

/// Profile screen showing user info, stats, and performance
struct ProfileView: View {
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel
    var onLogout: (() -> Void)?
    var onAccountDeleted: (() -> Void)?
    @Binding var selectedTab: HomeTab
    @Binding var navigationPath: NavigationPath

    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    @State private var isLoadingLastMatchDetail = false

    private var user: User? { userSession.currentUser }
    
    var body: some View {
        VStack(spacing: 0) {
            if let loadError = userSession.error, user == nil {
                headerBar

                FMFullScreenError(
                    title: loadError.apiErrorTitle ?? L10n.ErrorOverlay.title,
                    message: loadError.apiErrorMessage ?? L10n.ErrorOverlay.fullScreenMessage,
                    retryTitle: L10n.Common.retry,
                    onRetry: {
                        Task {
                            await userSession.fetchProfile()
                            await homeViewModel.load()
                        }
                    }
                )
            } else {
                profileScaffold
            }
        }
        .background(FMColors.background)
        .fmToast(
            userSession.refreshErrorMessage ?? L10n.ErrorOverlay.refreshMessage,
            isPresented: $userSession.refreshFailed,
            style: .error
        )
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(
                onLogout: onLogout,
                onAccountDeleted: onAccountDeleted,
                paymentMethodsViewModel: PaymentMethodsViewModel(paymentService: PaymentService()),
                paymentHistoryViewModelFactory: {
                    PaymentHistoryViewModel(paymentService: PaymentService())
                }
            )
        }
        .navigationDestination(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .alert(L10n.Profile.logoutTitle, isPresented: $showLogoutAlert) {
            Button(L10n.Profile.logoutConfirm, role: .destructive) {
                onLogout?()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Profile.logoutMessage)
        }
    }
    
    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Left-aligned logo (matches Home) — tapping it switches to the Home tab
            FMBrandLogo {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = .home
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.onSurface)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Button {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.error)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Header (collapsing)

    private var profilePicURL: URL? {
        if let urlStr = homeViewModel.profileImageUrl, let url = URL(string: urlStr) {
            return url
        }
        return user?.profilePicURL
    }

    private var profileScaffold: some View {
        ProfileScaffold(
            identity: ProfileIdentity(
                name: user?.fullName ?? "—",
                avatarURL: profilePicURL,
                defaultAvatarAssetName: user?.gender?.defaultAvatarAssetName ?? "defaultAvatar"
            ),
            trailingReserve: 112,
            showsBarScrim: true,
            bottomPadding: FMTabBar.contentBreathingSpace,
            onAvatarTap: { showEditProfile = true },
            onRefresh: {
                await userSession.fetchProfile()
                await homeViewModel.load()
            },
            leading: { context in
                // The brand leaves once the avatar is about to take its place.
                FMBrandLogo(isRevealed: context.progress < Self.brandHideProgress, interColor: context.foreground) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = .home
                    }
                }
            },
            trailing: { context in
                HStack(spacing: 8) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(context.foreground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Button {
                        showLogoutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(FMColors.error)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            },
            meta: {
                VStack(spacing: 16) {
                    countryAndPosition
                    editButton
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 24) {
                    statsSection
                    performanceSection
                    lastMatchSection
                }
            }
        )
    }

    private static let brandHideProgress: CGFloat = 0.38

    private var countryAndPosition: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(user?.countryFlag ?? "🏳️")
                    .font(.system(size: 14))

                Text(user?.countryDisplayName ?? "—")
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }

            if let position = user?.playerPosition {
                HStack(spacing: 6) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 12, weight: .medium))
                    Text(position.displayName)
                        .font(FMTypography.labelMedium)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
    }

    private var editButton: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))

                Text(L10n.Profile.editProfile)
                    .font(FMTypography.labelLarge)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .contentShape(Rectangle())
        }
    }

    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.statistics)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .padding(.horizontal, 24)

            // All four stay visible: equal-width cards share the row instead of scrolling.
            HStack(spacing: 8) {
                FMStatCard(icon: "trophy.fill",       value: user?.stats?.mvpCount ?? 0,      label: L10n.Profile.mvp, width: nil, contentPadding: 10)
                FMStatCard(icon: "star.fill",         value: user?.stats?.matchesWon ?? 0,    label: L10n.Profile.won, width: nil, contentPadding: 10)
                FMStatCard(icon: "sportscourt",       value: user?.stats?.matchesPlayed ?? 0, label: L10n.Profile.played, width: nil, contentPadding: 10)
                FMStatCard(icon: "soccerball",        value: user?.stats?.totalGoals ?? 0,    label: L10n.Profile.totalGoals, width: nil, contentPadding: 10)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.performance)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Profile.playerLevel)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                    
                    Text(user?.level.displayName ?? "—")
                        .font(FMTypography.titleLarge)
                        .foregroundColor(FMColors.onBackground)
                }
                
                Spacer()
                
                FMOVRRing(score: homeViewModel.averageScore)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Last Match Section

    @ViewBuilder
    private var lastMatchSection: some View {
        if homeViewModel.isLoading && homeViewModel.lastMatch == nil {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.LastMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                FMLastMatchSkeleton()
            }
            .padding(.horizontal, 24)
        } else if let last = homeViewModel.lastMatch {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.LastMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)

                LastMatchCard(match: last, isLoading: isLoadingLastMatchDetail) {
                    // Same re-entry guard as Home: the detail is fetched before navigating.
                    guard !isLoadingLastMatchDetail else { return }
                    isLoadingLastMatchDetail = true
                    Task {
                        defer { isLoadingLastMatchDetail = false }
                        if let detail = await homeViewModel.fetchLastMatchDetail() {
                            navigationPath.append(detail)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.LastMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)

                FMEmptyStateCard(
                    icon: "soccerball",
                    message: L10n.LastMatch.empty,
                    actionLabel: L10n.LastMatch.emptyAction,
                    onActionTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = .matches
                        }
                    }
                )
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView(selectedTab: .constant(.profile), navigationPath: .constant(NavigationPath()))
}
