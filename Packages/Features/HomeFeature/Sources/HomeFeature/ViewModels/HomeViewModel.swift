import Foundation
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

    private let homeService: HomeServiceProtocol
    private static let cacheKey = "home.cache.homeDataDTO"

    init(homeService: HomeServiceProtocol = HomeService()) {
        self.homeService = homeService
        // Pre-load from cache so the first render already has data
        if let cached = HomeViewModel.loadCache() {
            apply(cached)
        }
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
        } catch {
            #if DEBUG
            print("❌ HomeViewModel: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
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
                    teamBScore: $0.teamBScore
                )
            }
        )
        if let encoded = try? JSONEncoder().encode(dto) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
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
                    teamBScore: $0.teamBScore
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
}
