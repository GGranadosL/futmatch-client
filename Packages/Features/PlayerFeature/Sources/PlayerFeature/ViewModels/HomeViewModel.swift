import Foundation
import Combine
import NetworkFramework
import SharedModels

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var greetingName: String = ""
    @Published private(set) var level: PlayerLevel = .beginner
    @Published private(set) var averageScore: Int = 0
    @Published private(set) var profileImageUrl: String?
    @Published private(set) var suggestedMatches: [MatchItem] = []
    @Published private(set) var lastMatch: LastMatch?
    @Published private(set) var isLoading: Bool = false
    /// True only when there is no cached content AND the last load failed —
    /// drives the full-screen error state.
    @Published private(set) var loadFailed: Bool = false
    /// API-provided title/message for the full-screen error (nil → generic copy).
    @Published private(set) var loadErrorTitle: String?
    @Published private(set) var loadErrorMessage: String?
    /// Toggled true when a refresh fails but cached content is still shown —
    /// drives a transient error toast. The view resets it after display.
    @Published var refreshFailed: Bool = false
    /// API-provided message for the refresh toast (nil → generic copy).
    @Published private(set) var refreshErrorMessage: String?

    /// Whether we currently have content to show (from cache or a successful load).
    private var hasData = false

    private let homeService: HomeServiceProtocol
    private let fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    static let cacheKey = "home.cache.homeDataDTO"

    init(
        homeService: HomeServiceProtocol = HomeService(),
        fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol = FetchMatchDetailUseCase(matchService: MatchService())
    ) {
        self.homeService = homeService
        self.fetchMatchDetailUseCase = fetchMatchDetailUseCase
        // Pre-load from cache so the first render already has data
        if let cached = HomeViewModel.loadCache() {
            apply(cached)
            hasData = true
        }
        observeMembershipChanges()
    }

    /// Suggestions minus the matches the user is already enrolled in. `/home` and
    /// `/match/my-matches` are separate requests, so right after a booking the
    /// carousel can still list the match that "Your next match" already shows.
    /// Filtering against the reserved list hides it the moment that list updates,
    /// without waiting for `/home` to come back.
    func visibleSuggestions(excluding enrolledIds: Set<String>) -> [MatchItem] {
        suggestedMatches.filter { !enrolledIds.contains($0.id) }
    }

    func fetchLastMatchDetail() async -> MatchItem? {
        guard let matchId = lastMatch?.matchId else { return nil }
        return try? await fetchMatchDetailUseCase.execute(matchId: matchId)
    }

    func load() async {
        isLoading = true
        do {
            let data = try await homeService.fetchHome()
            greetingName = data.greetingName
            level = data.level
            averageScore = data.averageScore
            profileImageUrl = data.profileImageUrl
            suggestedMatches = data.suggestedMatches
            lastMatch = data.lastMatch
            HomeViewModel.saveCache(data)
            hasData = true
            loadFailed = false
        } catch {
            guard !error.isCancellation else {
                isLoading = false
                return
            }
            // Full-screen error only when we have nothing to display;
            // otherwise surface a transient toast over the cached content.
            if hasData {
                refreshErrorMessage = error.apiErrorMessage
                refreshFailed = true
            } else {
                loadErrorTitle = error.apiErrorTitle
                loadErrorMessage = error.apiErrorMessage
                loadFailed = true
            }
        }
        isLoading = false
    }

    // MARK: - Membership changes

    /// Reloads `/home` after the user joins, pays for, leaves or cancels a match,
    /// so the suggestions don't stay stale until a manual pull-to-refresh.
    /// A single booking posts the notification several times (join → RESERVED,
    /// payment confirmed, Firestore → JOINED); the debounce folds them into one request.
    private func observeMembershipChanges() {
        NotificationCenter.default.publisher(for: .matchMembershipDidChange)
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.load() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache (UserDefaults + Codable DTOs)

    private func apply(_ data: HomeData) {
        greetingName = data.greetingName
        level = data.level
        averageScore = data.averageScore
        profileImageUrl = data.profileImageUrl
        suggestedMatches = data.suggestedMatches
        lastMatch = data.lastMatch
    }

    private static func saveCache(_ data: HomeData) {
        // Re-encode via a lightweight Codable mirror to avoid making HomeData Codable
        let dto = HomeCachePayload(
            greetingName: data.greetingName,
            level: data.level,
            averageScore: data.averageScore,
            profileImageUrl: data.profileImageUrl,
            suggestedMatches: data.suggestedMatches.map {
                HomeCacheMatchItem(
                    id: $0.id,
                    venueName: $0.venueName,
                    timeRange: $0.timeRange,
                    date: $0.date,
                    startDate: $0.startDate,
                    price: $0.price,
                    matchType: $0.matchType,
                    spotsLeft: $0.spotsLeft,
                    fieldImageUrl: $0.fieldImageUrl
                )
            },
            lastMatch: data.lastMatch.map {
                HomeCacheLastMatch(
                    matchId: $0.matchId,
                    fieldName: $0.fieldName,
                    playedAt: $0.playedAt,
                    outcome: $0.outcome.rawValue,
                    teamAScore: $0.teamAScore,
                    teamBScore: $0.teamBScore,
                    teamAName: $0.teamA?.name,
                    teamAColor: $0.teamA?.colorHex,
                    teamBName: $0.teamB?.name,
                    teamBColor: $0.teamB?.colorHex
                )
            }
        )
        if let encoded = try? JSONEncoder().encode(dto) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private static func teamVisual(name: String?, color: String?) -> MatchTeamVisual? {
        name.map { MatchTeamVisual(name: $0, colorHex: color) }
    }

    private static func loadCache() -> HomeData? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let dto = try? JSONDecoder().decode(HomeCachePayload.self, from: data)
        else { return nil }

        return HomeData(
            greetingName: dto.greetingName,
            level: dto.level,
            averageScore: dto.averageScore,
            profileImageUrl: dto.profileImageUrl,
            suggestedMatches: dto.suggestedMatches.map {
                MatchItem(
                    id: $0.id,
                    venueName: $0.venueName,
                    timeRange: $0.timeRange,
                    date: $0.date,
                    startDate: $0.startDate,
                    price: $0.price,
                    matchType: $0.matchType,
                    spotsLeft: $0.spotsLeft,
                    fieldImageUrl: $0.fieldImageUrl
                )
            },
            lastMatch: dto.lastMatch.map {
                LastMatch(
                    matchId: $0.matchId,
                    fieldName: $0.fieldName,
                    playedAt: $0.playedAt,
                    outcome: LastMatchOutcome(rawValue: $0.outcome) ?? .draw,
                    teamAScore: $0.teamAScore,
                    teamBScore: $0.teamBScore,
                    teamA: Self.teamVisual(name: $0.teamAName, color: $0.teamAColor),
                    teamB: Self.teamVisual(name: $0.teamBName, color: $0.teamBColor)
                )
            }
        )
    }
}

// MARK: - Cache Models

private struct HomeCachePayload: Codable {
    let greetingName: String
    let level: PlayerLevel
    let averageScore: Int
    let profileImageUrl: String?
    let suggestedMatches: [HomeCacheMatchItem]
    let lastMatch: HomeCacheLastMatch?
}

private struct HomeCacheMatchItem: Codable {
    let id: String
    let venueName: String
    let timeRange: String
    let date: String
    let startDate: Date
    let price: String
    let matchType: String
    let spotsLeft: Int
    let fieldImageUrl: String?
}

private struct HomeCacheLastMatch: Codable {
    let matchId: String
    let fieldName: String
    let playedAt: Date
    let outcome: String
    let teamAScore: Int
    let teamBScore: Int
    // Optional so caches written before team identities still decode.
    let teamAName: String?
    let teamAColor: String?
    let teamBName: String?
    let teamBColor: String?
}
