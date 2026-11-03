import Foundation

// MARK: - Load cached ranking

protocol LoadCachedRankingUseCaseProtocol {
    func execute(_ query: RankingQuery) -> RankingBoard?
}

struct LoadCachedRankingUseCase: LoadCachedRankingUseCaseProtocol {
    private let repository: RankingRepositoryProtocol

    init(repository: RankingRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ query: RankingQuery) -> RankingBoard? {
        repository.cachedRanking(query)
    }
}

// MARK: - Fetch ranking

protocol FetchRankingUseCaseProtocol {
    func execute(_ query: RankingQuery, force: Bool) async throws -> RankingBoard
}

struct FetchRankingUseCase: FetchRankingUseCaseProtocol {
    private let repository: RankingRepositoryProtocol

    init(repository: RankingRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ query: RankingQuery, force: Bool) async throws -> RankingBoard {
        try await repository.fetchRanking(query, force: force)
    }
}
