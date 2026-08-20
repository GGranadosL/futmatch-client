import Foundation
import Combine
import CoreLocation
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
    /// Device's current coordinate, resolved once per session — used to show
    /// each match's distance on its card. Nil when permission was denied or
    /// the location couldn't be determined.
    @Published private(set) var userCoordinate: CLLocationCoordinate2D?

    private let fetchMyMatchesUseCase: FetchMyMatchesUseCaseProtocol
    private let fetchCurrentLocationUseCase: FetchCurrentLocationUseCaseProtocol?
    private let cacheRepo: MatchCacheRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchMyMatchesUseCase: FetchMyMatchesUseCaseProtocol,
        fetchCurrentLocationUseCase: FetchCurrentLocationUseCaseProtocol? = nil,
        cacheRepo: MatchCacheRepositoryProtocol? = nil
    ) {
        self.fetchMyMatchesUseCase = fetchMyMatchesUseCase
        self.fetchCurrentLocationUseCase = fetchCurrentLocationUseCase
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

        // Resolve the device's coordinate so match cards can show a distance.
        // Retries on every load until it succeeds — the shared service (see
        // `CurrentLocationService`) caches a successful fix and fast-paths a
        // denied/restricted status, so repeated calls are cheap once resolved
        // or once permission is settled.
        if userCoordinate == nil {
            if let coordinate = await fetchCurrentLocationUseCase?.execute() {
                userCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }

        // 2. Fetch fresh data from API
        do {
            let fresh = try await fetchMyMatchesUseCase.execute(lat: userCoordinate?.latitude, lon: userCoordinate?.longitude)
            myMatches = fresh
            try? cacheRepo?.saveMatches(fresh)
        } catch {
            guard !error.isCancellation else {
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

    /// The nearest upcoming match the user is enrolled in. Skips completed and
    /// canceled matches — without the status check a canceled match with a
    /// future kickoff still surfaced on Home as "your next match" even though
    /// the Reserved tab correctly filed it under Cancelados.
    var nextMatch: MatchItem? {
        let now = Date()
        return myMatches
            .filter { $0.startDate > now && $0.isUpcoming }
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
