import Foundation
import Combine
import NetworkFramework

// MARK: - Reserved Matches ViewModel

@MainActor
final class ReservedMatchesViewModel: ObservableObject {

    @Published private(set) var myMatches: [MatchItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    /// API-provided title for the full-screen error (nil → generic copy).
    @Published private(set) var errorTitle: String?
    /// Toggled true when a refresh fails but cached content is still shown —
    /// drives a transient error toast. The view resets it after display.
    @Published var refreshFailed: Bool = false
    /// API-provided message for the refresh toast (nil → generic copy).
    @Published private(set) var refreshErrorMessage: String?

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
            guard !(error is CancellationError) else {
                isLoading = false
                return
            }
            // If we already have cached data visible, keep it and surface a toast;
            // otherwise show the full-screen failed state.
            if cached.isEmpty {
                self.errorTitle = error.apiErrorTitle
                self.error = error.apiErrorMessage ?? error.localizedDescription
                myMatches = []
            } else {
                refreshErrorMessage = error.apiErrorMessage ?? error.localizedDescription
                refreshFailed = true
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
