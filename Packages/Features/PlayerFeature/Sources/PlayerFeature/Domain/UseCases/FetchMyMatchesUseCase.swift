import Foundation

// MARK: - Protocol

protocol FetchMyMatchesUseCaseProtocol {
    func execute(lat: Double?, lon: Double?) async throws -> [MatchItem]
}

// MARK: - Implementation

final class FetchMyMatchesUseCase: FetchMyMatchesUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        try await matchService.fetchMyMatches(lat: lat, lon: lon)
    }
}
