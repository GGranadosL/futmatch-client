import Foundation
import Combine
import PersistenceFramework

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

    private let fetchMatchesUseCase: FetchMatchesUseCaseProtocol
    private var cacheRepo: MatchCacheRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(fetchMatchesUseCase: FetchMatchesUseCaseProtocol) {
        self.fetchMatchesUseCase = fetchMatchesUseCase
        observeMembershipChanges()
    }

    func setCache(_ repo: MatchCacheRepositoryProtocol) {
        cacheRepo = repo
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
        guard case .idle = state else { return }

        // 1. Show cached matches instantly if available
        let cached = cacheRepo?.loadMatches() ?? []
        if !cached.isEmpty {
            state = .loaded(groupByDate(cached))
            isRefreshing = true
        } else {
            state = .loading
        }

        // 2. Fetch fresh data from API
        do {
            let matches = try await fetchMatchesUseCase.execute(lat: lat, lon: lon)
            state = .loaded(groupByDate(matches))
            try? cacheRepo?.saveMatches(matches)
        } catch {
            // If we already have cached data visible, keep it — don't replace with error
            if case .loaded = state { /* silent failure */ } else {
                state = .failed(error.localizedDescription)
            }
        }

        isRefreshing = false
    }

    func reload(lat: Double? = nil, lon: Double? = nil) async {
        state = .idle
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

    private func groupByDate(_ matches: [MatchItem]) -> [MatchSection] {
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
