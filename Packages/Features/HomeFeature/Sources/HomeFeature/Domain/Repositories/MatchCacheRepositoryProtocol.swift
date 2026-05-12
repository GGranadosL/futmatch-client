import Foundation

// MARK: - Match Cache Repository Protocol

protocol MatchCacheRepositoryProtocol {
    func saveMatches(_ items: [MatchItem]) throws
    func loadMatches() -> [MatchItem]
    func clearMatches() throws
}
