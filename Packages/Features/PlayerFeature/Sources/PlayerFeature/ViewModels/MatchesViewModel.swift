import Foundation
import Combine
import PersistenceFramework
import NetworkFramework

// MARK: - MatchesViewModel

@MainActor
final class MatchesViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([MatchSection])
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isRefreshing: Bool = false
    /// API-provided title/message for the full-screen error (nil → generic copy).
    @Published private(set) var loadErrorTitle: String?
    @Published private(set) var loadErrorMessage: String?
    /// Toggled true when a refresh fails but loaded content is still shown —
    /// drives a transient error toast. The view resets it after display.
    @Published var refreshFailed: Bool = false
    /// API-provided message for the refresh toast (nil → generic copy).
    @Published private(set) var refreshErrorMessage: String?

    private let fetchMatchesUseCase: FetchMatchesUseCaseProtocol
    private let cacheRepo: MatchCacheRepositoryProtocol?
    private let region: MatchRegion
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchMatchesUseCase: FetchMatchesUseCaseProtocol,
        cacheRepo: MatchCacheRepositoryProtocol? = nil,
        region: MatchRegion = .default
    ) {
        self.fetchMatchesUseCase = fetchMatchesUseCase
        self.cacheRepo = cacheRepo
        self.region = region
        // Pre-load cache synchronously so the first render already has data
        if let cached = cacheRepo?.loadMatches(), !cached.isEmpty {
            state = .loaded(MatchesViewModel.buildSections(from: cached))
        }
        observeMembershipChanges()
        observeRegionalUpdates()
    }

    // MARK: - Derived State

    var sections: [MatchSection] {
        guard case .loaded(let s) = state else { return [] }
        return s
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var nextMatch: MatchItem? {
        let userId = KeychainManager.shared.userId
        return allMatches.first { match in
            let players = match.teamAPlayers + match.teamBPlayers
            return players.contains { $0.playerId == userId && $0.status == .joined }
        }
    }
    var allMatches: [MatchItem] { sections.flatMap { $0.matches } }

    // MARK: - Actions

    func loadMatches(lat: Double? = nil, lon: Double? = nil) async {
        // Block only if already fetching to avoid duplicate requests
        if case .loading = state { return }

        // 1. Show cached matches instantly — if already showing loaded data (from
        //    cache pre-loaded in init) just set refreshing so the UI doesn't flicker
        let cached = cacheRepo?.loadMatches() ?? []
        if case .loaded = state {
            isRefreshing = true
        } else if !cached.isEmpty {
            state = .loaded(groupByDate(cached))
            isRefreshing = true
        } else {
            state = .loading
        }

        // 2. Fetch fresh data from API (versioned — may report no changes)
        do {
            let result = try await fetchMatchesUseCase.execute(region: region, lat: lat, lon: lon)
            switch result {
            case .changed(let matches, _):
                state = .loaded(groupByDate(matches))
                try? cacheRepo?.saveMatches(matches)
            case .unchanged:
                // Region version unchanged — keep the current list. If nothing
                // was loaded yet (e.g. cache miss), fall back to whatever cache holds.
                if case .loaded = state {
                    // already showing data, nothing to do
                } else {
                    state = .loaded(groupByDate(cached))
                }
            }
        } catch {
            guard !(error is CancellationError) else {
                isRefreshing = false
                return
            }
            // If we already have data visible, keep it and surface a toast;
            // otherwise show the full-screen failed state.
            if case .loaded = state {
                refreshErrorMessage = error.apiErrorMessage
                refreshFailed = true
            } else {
                loadErrorTitle = error.apiErrorTitle
                loadErrorMessage = error.apiErrorMessage
                state = .failed(error.localizedDescription)
            }
        }

        isRefreshing = false
    }

    func reload(lat: Double? = nil, lon: Double? = nil) async {
        // Reset to idle so loadMatches doesn't skip the loading state
        if case .loaded = state { /* keep data visible while refreshing */ }
        else { state = .idle }
        // Run in a detached-like context so SwiftUI .refreshable cancellation
        // doesn't abort the network request when the user releases the pull gesture.
        await Task {
            await loadMatches(lat: lat, lon: lon)
        }.value
    }

    // MARK: - Private

    private func observeMembershipChanges() {
        NotificationCenter.default.publisher(for: .matchMembershipDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.reload() }
            }
            .store(in: &cancellables)
    }

    /// Auto-refresh when a regional data-only push (`matches_updated`) arrives.
    /// Re-runs the V2 fetch with the stored `sinceVersion`; the backend answers
    /// `hasChanges=false` if this client already has the latest version, so the
    /// extra call is cheap. Ignores pushes for other regions.
    private func observeRegionalUpdates() {
        NotificationCenter.default.publisher(for: .matchesRegionDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if let pushedRegion = note.userInfo?["region"] as? String,
                   pushedRegion != self.region.key {
                    return
                }
                Task { await self.reload() }
            }
            .store(in: &cancellables)
    }

    static func buildSections(from matches: [MatchItem]) -> [MatchSection] {
        MatchesViewModel.groupByDateStatic(matches)
    }

    private func groupByDate(_ matches: [MatchItem]) -> [MatchSection] {
        MatchesViewModel.groupByDateStatic(matches)
    }

    private static func groupByDateStatic(_ matches: [MatchItem]) -> [MatchSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        var grouped: [Date: [MatchItem]] = [:]
        for match in matches {
            grouped[calendar.startOfDay(for: match.startDate), default: []].append(match)
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEEE d"

        return grouped.keys.sorted().compactMap { day in
            let dayMatches = grouped[day] ?? []
            guard !dayMatches.isEmpty else { return nil }
            let title: String
            if calendar.isDate(day, inSameDayAs: today) {
                title = L10n.Matches.today
            } else if calendar.isDate(day, inSameDayAs: tomorrow) {
                title = L10n.Matches.tomorrow
            } else {
                title = fmt.string(from: day).capitalized
            }
            return MatchSection(title: title, matches: dayMatches)
        }
    }
}
