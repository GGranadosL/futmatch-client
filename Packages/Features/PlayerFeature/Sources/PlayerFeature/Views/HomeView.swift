import SwiftUI
import FMDesignSystem
import SharedModels
import AdminFeature

/// Main Home screen showing greeting, next game, suggested games, and last match
struct HomeContentView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var reservedViewModel: ReservedMatchesViewModel
    @EnvironmentObject private var notificationsViewModel: NotificationsViewModel
    @EnvironmentObject private var userSession: UserSession
    @Binding var selectedTab: HomeTab
    @Binding var navigationPath: NavigationPath
    var onLogout: (() -> Void)?
    var isDemoMode: Bool = false

    @State private var showNotifications = false
    @State private var showAdmin = false

    /// `ADMIN` and `ORGANIZER` users see the admin-panel button next to the bell,
    /// unless `admin_feature_enabled` Remote Config flag is set to false.
    private var isAdmin: Bool {
        guard AdminRemoteConfig().isAdminFeatureEnabled else { return false }
        let role = userSession.currentUser?.userRole
        return role == .administrator || role == .organizer
    }

    private var nextMatch: MatchItem? { reservedViewModel.nextMatch }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if homeViewModel.loadFailed {
                FMFullScreenError(
                    title: homeViewModel.loadErrorTitle ?? L10n.ErrorOverlay.title,
                    message: homeViewModel.loadErrorMessage ?? L10n.ErrorOverlay.fullScreenMessage,
                    retryTitle: L10n.Common.retry,
                    onRetry: {
                        Task {
                            await homeViewModel.load()
                            await reservedViewModel.load()
                        }
                    }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        greetingSection
                        nextGameSection
                        suggestedGamesSection
                        lastMatchSection
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    // Use an unstructured Task so the network requests aren't cancelled
                    // when `.task(id: effectiveProfileImageUrl)` in HomeContainerView
                    // restarts due to profileImageUrl changing mid-load.
                    await Task {
                        await homeViewModel.load()
                        await reservedViewModel.load()
                    }.value
                }
            }
        }
        .background(FMColors.background)
        .fmToast(
            homeViewModel.refreshErrorMessage ?? L10n.ErrorOverlay.refreshMessage,
            isPresented: $homeViewModel.refreshFailed,
            style: .error
        )
        .navigationDestination(isPresented: $showNotifications) {
            NotificationsView(navigationPath: $navigationPath)
                .environmentObject(notificationsViewModel)
        }
        .navigationDestination(isPresented: $showAdmin) {
            AdminPanelView()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            FMBrandLogo()

            Spacer()

            headerActions
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// On iOS 26+ both actions live inside a single Liquid Glass capsule (like
    /// the Photos app toolbar), each labelled with its title. On older OSes the
    /// buttons render plainly over the solid background.
    @ViewBuilder
    private var headerActions: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if isAdmin {
                        adminButton
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    notificationsButton
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        } else {
            HStack(spacing: 8) {
                if isAdmin { adminButton }
                notificationsButton
            }
        }
    }

    private var adminButton: some View {
        Button {
            showAdmin = true
        } label: {
            Image("admin_panel_settings", bundle: .main)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundColor(FMColors.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private var notificationsButton: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image("notifications", bundle: .main)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                if notificationsViewModel.unreadCount > 0 {
                    Text(notificationsViewModel.unreadCount > 99 ? "99+" : "\(notificationsViewModel.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(FMColors.error)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -6)
                }
            }
            .foregroundColor(FMColors.onSurface)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.greeting(homeViewModel.greetingName))
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(FMColors.onBackground)

                Text(homeViewModel.level.displayName)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }

            Spacer()

            FMRatingBadge(score: homeViewModel.averageScore, label: L10n.rating)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Next Game Section

    private var nextGameSection: some View {
        Group {
            if let match = nextMatch {
                FMNextGameCard(
                    title: L10n.NextGame.title,
                    dateLabel: match.date,
                    time: match.timeRange,
                    location: match.location,
                    detailLabel: L10n.NextGame.viewDetail,
                    fieldImageUrl: match.fieldImageUrl,
                    onDetailTap: {
                        navigationPath.append(match)
                    }
                )
            } else if reservedViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .tint(FMColors.primary)
            } else {
                FMEmptyStateCard(
                    icon: "calendar",
                    message: L10n.NextGame.empty,
                    actionLabel: L10n.NextGame.joinMatch,
                    onActionTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = .matches
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Suggested Games Section

    private var suggestedGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.SuggestedGames.title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .padding(.horizontal, 24)

            let suggestions = homeViewModel.suggestedMatches
            let isLoading = homeViewModel.isLoading && suggestions.isEmpty

            if isLoading {
                // Skeleton while loading for the first time
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in FMGameCardSkeleton() }
                    }
                    .padding(.horizontal, 24)
                }
                .disabled(true)
            } else if suggestions.isEmpty {
                FMEmptyStateCard(
                    icon: "soccerball",
                    message: L10n.SuggestedGames.empty
                )
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { match in
                            FMGameCard(
                                venueName: match.venueName,
                                price: match.price,
                                timeRange: match.timeRange,
                                fieldImageUrl: match.fieldImageUrl,
                                onTap: {
                                    navigationPath.append(match)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Last Match Section

    private var lastMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.LastMatch.title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            if homeViewModel.isLoading && homeViewModel.lastMatch == nil {
                FMLastMatchSkeleton()
            } else if let last = homeViewModel.lastMatch {
                HStack(spacing: 14) {
                    Image(systemName: outcomeIcon(last.outcome))
                        .font(.system(size: 24))
                        .foregroundColor(outcomeColor(last.outcome))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(outcomeColor(last.outcome).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.outcomeLabel)
                            .font(FMTypography.titleSmall)
                            .foregroundColor(FMColors.onSurface)
                        Text("\(last.relativeDate) - \(last.fieldName)")
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Spacer()

                    Text("\(last.teamAScore) - \(last.teamBScore)")
                        .font(FMTypography.headlineMedium)
                        .foregroundColor(FMColors.onSurface)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FMColors.surfaceContainerLowest)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(FMColors.outlineVariant, lineWidth: 1)
                )
            } else {
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
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Outcome Helpers

    private func outcomeIcon(_ outcome: LastMatchOutcome) -> String {
        switch outcome {
        case .win: return "trophy.fill"
        case .loss: return "xmark.circle.fill"
        case .draw: return "equal.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: LastMatchOutcome) -> Color {
        switch outcome {
        case .win: return .green
        case .loss: return .red
        case .draw: return .orange
        }
    }
}

// MARK: - Preview
#Preview {
    let factory = PlayerDependencyFactory()
    HomeContentView(selectedTab: .constant(.home), navigationPath: .constant(NavigationPath()))
        .environmentObject(HomeViewModel())
        .environmentObject(ReservedMatchesViewModel(fetchMyMatchesUseCase: factory.makeFetchMyMatchesUseCase()))
}
