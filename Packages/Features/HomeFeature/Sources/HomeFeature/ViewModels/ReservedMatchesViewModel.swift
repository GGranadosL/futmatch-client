import Foundation
import Combine

// MARK: - Reserved Matches ViewModel

@MainActor
final class ReservedMatchesViewModel: ObservableObject {

    @Published private(set) var myMatches: [MatchItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let fetchMyMatchesUseCase: FetchMyMatchesUseCaseProtocol
    private let cacheRepo: MatchCacheRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchMyMatchesUseCase: FetchMyMatchesUseCaseProtocol,
        cacheRepo: MatchCacheRepositoryProtocol? = nil
    ) {
        self.fetchMyMatchesUseCase = fetchMyMatchesUseCase
        self.cacheRepo = cacheRepo
        // Pre-load cache synchronously so the first render already has data
        if let cached = cacheRepo?.loadMatches(), !cached.isEmpty {
            myMatches = cached
        }
        observeMembershipChanges()
    }

    func load() async {
        // 1. Show cached matches instantly if available
        let cached = cacheRepo?.loadMatches() ?? []
        if !cached.isEmpty {
            myMatches = cached
            isLoading = false
        } else {
            isLoading = true
        }
        error = nil

        // 2. Fetch fresh data from API
        do {
            let fresh = try await fetchMyMatchesUseCase.execute(lat: nil, lon: nil)
            myMatches = fresh
            try? cacheRepo?.saveMatches(fresh)
        } catch {
            // If we already have cached data visible, keep it — don't replace with error
            if cached.isEmpty {
                self.error = error.localizedDescription
                myMatches = []
            }
        }
        isLoading = false
    }

    /// The nearest upcoming match the user is enrolled in
    var nextMatch: MatchItem? {
        let now = Date()
        return myMatches
            .filter { $0.startDate > now }
            .min { $0.startDate < $1.startDate }
    }

    // MARK: - Private

    private func observeMembershipChanges() {
        NotificationCenter.default.publisher(for: .matchMembershipDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.load() }
            }
            .store(in: &cancellables)
    }
}
