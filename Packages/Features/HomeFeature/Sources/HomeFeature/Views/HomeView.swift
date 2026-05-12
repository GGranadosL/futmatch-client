import SwiftUI
import FMDesignSystem
import SharedModels

/// Main Home screen showing greeting, next game, suggested games, and last match
struct HomeContentView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var reservedViewModel: ReservedMatchesViewModel
    @Binding var selectedTab: HomeTab
    @Binding var navigationPath: NavigationPath
    var onLogout: (() -> Void)?

    private var nextMatch: MatchItem? { reservedViewModel.nextMatch }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

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
                await homeViewModel.load()
                await reservedViewModel.load()
            }
        }
        .background(FMColors.background)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image("logo_futmatch", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text("FutMatch")
                    .font(FMTypography.title2)
                    .foregroundColor(FMColors.primary)
            }

            Spacer()

            Button {
                // Notifications action
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FMColors.onSurface)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.greeting(homeViewModel.greetingName))
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(FMColors.onBackground)

                Text(homeViewModel.level)
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
                FMNextGameEmptyCard(
                    emptyMessage: L10n.NextGame.empty,
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
            if suggestions.isEmpty && !homeViewModel.isLoading {
                Text(L10n.Matches.noMatchesAvailable)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { match in
                            FMGameCard(
                                venueName: match.venueName,
                                price: match.price,
                                timeRange: match.timeRange,
                                fieldImageUrl: match.fieldImageUrl
                            )
                            .onTapGesture {
                                navigationPath.append(match)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Last Match Section

    private var lastMatchSection: some View {
        Group {
            if let last = homeViewModel.lastMatch {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.LastMatch.title)
                        .font(FMTypography.titleLarge)
                        .foregroundColor(FMColors.onBackground)

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
                }
                .padding(.horizontal, 24)
            }
        }
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
    let factory = HomeDependencyFactory()
    HomeContentView(selectedTab: .constant(.home), navigationPath: .constant(NavigationPath()))
        .environmentObject(HomeViewModel())
        .environmentObject(ReservedMatchesViewModel(fetchMyMatchesUseCase: factory.makeFetchMyMatchesUseCase()))
}
