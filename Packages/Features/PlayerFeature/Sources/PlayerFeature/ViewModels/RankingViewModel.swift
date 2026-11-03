import Foundation
import NetworkFramework

/// State of the monthly ranking screen. The selected season and category live only here:
/// they are never saved, so every new entry from Home starts on the current month and Victories.
@MainActor
final class RankingViewModel: ObservableObject {

    @Published private(set) var season: RankingSeason
    /// Current month plus the three before it, anchored to the month the screen opened on.
    let seasons: [RankingSeason]
    @Published private(set) var category: RankingCategory = .victories
    @Published private(set) var board: RankingBoard?
    /// First load with nothing to show yet → skeleton.
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingMore = false
    /// The load failed and there is nothing to show → full error with retry.
    @Published private(set) var hasError = false
    /// The last "load more" failed → the button turns into "Retry".
    @Published private(set) var loadMoreError = false
    @Published var isAboutExpanded = false
    /// A failure while rows stay visible → error toast. The view clears it after showing.
    @Published var errorMessage: String?

    let communityId: String

    private let loadCachedRanking: LoadCachedRankingUseCaseProtocol
    private let fetchRanking: FetchRankingUseCaseProtocol
    private var request: Task<Void, Never>?
    /// Bumped on every season/category switch, so a late answer for the previous
    /// selection is dropped instead of replacing the current one.
    private var generation = 0
    private var hasStarted = false

    init(
        season: RankingSeason,
        communityId: String,
        loadCachedRanking: LoadCachedRankingUseCaseProtocol,
        fetchRanking: FetchRankingUseCaseProtocol
    ) {
        self.season = season
        self.seasons = season.selectableSeasons
        self.communityId = communityId
        self.loadCachedRanking = loadCachedRanking
        self.fetchRanking = fetchRanking
    }

    // MARK: - Actions

    /// Call when the screen appears. Runs once; coming back from a pushed screen keeps the state.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        select(category: category, season: season)
    }

    func selectSeason(_ newSeason: RankingSeason) {
        guard seasons.contains(newSeason), newSeason != season else { return }
        select(category: category, season: newSeason)
    }

    func selectCategory(_ newCategory: RankingCategory) {
        guard newCategory != category else { return }
        select(category: newCategory, season: season)
    }

    /// Pull to refresh: page 1 from the network, ignoring the cache's age.
    func refresh() async {
        startLoad(force: true, more: false)
        await request?.value
    }

    func retry() {
        startLoad(force: true, more: false)
    }

    func loadMore() {
        guard board?.hasMore == true, request == nil else { return }
        startLoad(force: false, more: true)
    }

    func toggleAbout() {
        isAboutExpanded.toggle()
    }

    // MARK: - Loading

    private func select(category: RankingCategory, season: RankingSeason) {
        request?.cancel()
        request = nil
        generation += 1
        self.category = category
        self.season = season
        board = loadCachedRanking.execute(query(page: 1))
        hasError = false
        loadMoreError = false
        isRefreshing = false
        isLoadingMore = false
        startLoad(force: false, more: false)
    }

    private func query(page: Int) -> RankingQuery {
        RankingQuery(season: season, communityId: communityId, category: category, page: page)
    }

    private func startLoad(force: Bool, more: Bool) {
        request?.cancel()
        let currentGeneration = generation
        let page = more ? (board?.page ?? 0) + 1 : 1
        let query = query(page: page)
        isLoading = !more && !force && board == nil
        isRefreshing = force
        isLoadingMore = more
        hasError = false
        loadMoreError = false
        request = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.fetchRanking.execute(query, force: force)
                guard currentGeneration == self.generation, !Task.isCancelled else { return }
                if more, let previous = self.board {
                    self.board = previous.appending(result)
                } else {
                    self.board = result
                }
                self.finishLoading()
            } catch {
                // A cancelled request belongs to a selection that's already gone: no error.
                guard currentGeneration == self.generation, !Task.isCancelled, !error.isCancellation else { return }
                let hasData = self.board != nil
                self.finishLoading()
                self.hasError = !hasData
                self.loadMoreError = more
                if hasData {
                    self.errorMessage = error.apiErrorMessage ?? L10n.Ranking.refreshFailed
                }
            }
        }
    }

    private func finishLoading() {
        isLoading = false
        isRefreshing = false
        isLoadingMore = false
        request = nil
    }
}
