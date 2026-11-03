import SwiftUI
import FMDesignSystem

/// Pushed from Home's Ranking card. Always opens on the device's current month and Victories.
struct RankingRoute: Hashable {
    let season: RankingSeason
    let communityId: String
}

/// Monthly player ranking: season selector, Victories / Top scorers, podium and the
/// paginated standings. Back is the system button.
struct RankingView: View {
    @StateObject private var viewModel: RankingViewModel
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    init(viewModel: @autoclosure @escaping () -> RankingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                RankingHeaderCard(community: viewModel.board?.community)
                seasonRow
                RankingCategoryToggle(selected: viewModel.category, onSelect: viewModel.selectCategory)
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.refresh() }
        .background(FMColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { yourPositionBar }
        .navigationTitle(L10n.Ranking.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .modifier(HideTabBarModifier())
        .task { viewModel.start() }
        .onChange(of: viewModel.errorMessage) { message in
            guard let message else { return }
            errorToastMessage = message
            showErrorToast = true
            viewModel.errorMessage = nil
        }
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
    }

    // MARK: - Season

    private var seasonRow: some View {
        HStack(spacing: 8) {
            RankingSeasonPicker(
                seasons: viewModel.seasons,
                selected: viewModel.season,
                onSelect: viewModel.selectSeason
            )
            Text(L10n.Ranking.monthlySeason)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onPrimaryContainer)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Capsule().fill(FMColors.primaryContainer))
                .fixedSize()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let board = viewModel.board {
            if board.players.isEmpty {
                RankingMessage(title: L10n.Ranking.emptyTitle) {
                    Text(L10n.Ranking.emptyDescription)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
            } else {
                standings(board)
            }
        } else if viewModel.hasError {
            RankingMessage(title: L10n.Ranking.loadFailed) {
                Button(L10n.Ranking.retry) { viewModel.retry() }
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)
            }
        } else {
            RankingSkeleton()
        }
    }

    @ViewBuilder
    private func standings(_ board: RankingBoard) -> some View {
        if !board.podium.isEmpty {
            RankingPodium(players: board.podium, category: viewModel.category)
        }

        Text(L10n.Ranking.classificationTitle)
            .font(.interSemiBold(size: 22))
            .foregroundColor(FMColors.onBackground)
            .accessibilityAddTraits(.isHeader)

        RankingTableHeader(category: viewModel.category)

        ForEach(board.players) { player in
            RankingPlayerRow(
                player: player,
                category: viewModel.category,
                isCurrentUser: player.id == board.currentUser?.id
            )
        }

        if board.hasMore {
            loadMoreRow
        }

        RankingFooter(
            calculatedAt: board.calculatedAt,
            seasonTimeZone: board.period.timeZone,
            showParticipationHint: board.currentUser == nil,
            isExpanded: viewModel.isAboutExpanded,
            onToggle: viewModel.toggleAbout
        )
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMore {
                ProgressView().tint(FMColors.primary)
            } else {
                Button(viewModel.loadMoreError ? L10n.Ranking.retry : L10n.Ranking.loadMore) {
                    viewModel.loadMore()
                }
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.primary)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    // MARK: - Your position

    /// Your row when you're ranked but not among the rows loaded so far. It sits in its
    /// own area so the table keeps the server's order.
    @ViewBuilder
    private var yourPositionBar: some View {
        if let board = viewModel.board,
           !board.players.isEmpty,
           let current = board.currentUser,
           !board.currentUserIsListed {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Ranking.yourPosition)
                    .font(FMTypography.labelMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                RankingPlayerRow(player: current, category: viewModel.category, isCurrentUser: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FMColors.surfaceContainer.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Divider() }
        }
    }
}

// MARK: - Hide Tab Bar

private struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}
