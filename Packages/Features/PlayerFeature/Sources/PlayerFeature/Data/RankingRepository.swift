import Foundation
import NetworkFramework

// MARK: - Protocol

protocol RankingRepositoryProtocol {
    /// The stored page, however old, so the screen can paint before the network answers.
    func cachedRanking(_ query: RankingQuery) -> RankingBoard?
    /// A stored page younger than the TTL is returned as is (an empty one too). Otherwise
    /// the network is asked; if that fails, the stored page is the fallback. `force`
    /// (pull to refresh) always asks the network and surfaces its error.
    func fetchRanking(_ query: RankingQuery, force: Bool) async throws -> RankingBoard
}

// MARK: - Implementation

struct RankingRepository: RankingRepositoryProtocol {
    static let timeToLive: TimeInterval = 6 * 60 * 60

    private let service: RankingServiceProtocol
    private let cache: RankingCacheStore
    private let now: () -> Date

    init(service: RankingServiceProtocol, cache: RankingCacheStore, now: @escaping () -> Date = Date.init) {
        self.service = service
        self.cache = cache
        self.now = now
    }

    func cachedRanking(_ query: RankingQuery) -> RankingBoard? {
        cache.entry(for: query)?.board
    }

    func fetchRanking(_ query: RankingQuery, force: Bool) async throws -> RankingBoard {
        let stored = cache.entry(for: query)
        if !force, let stored, now().timeIntervalSince(stored.savedAt) < Self.timeToLive {
            return stored.board
        }
        do {
            let board = try await service.fetchRanking(query)
            cache.save(board, for: query, at: now())
            return board
        } catch {
            if !force, !error.isCancellation, let stored {
                return stored.board
            }
            throw error
        }
    }
}
