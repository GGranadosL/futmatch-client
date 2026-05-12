import Foundation

// MARK: - Protocol

protocol FetchMatchesUseCaseProtocol {
    func execute(lat: Double?, lon: Double?) async throws -> [MatchItem]
}

// MARK: - Implementation

final class FetchMatchesUseCase: FetchMatchesUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        try await matchService.fetchMatches(lat: lat, lon: lon)
    }
}
