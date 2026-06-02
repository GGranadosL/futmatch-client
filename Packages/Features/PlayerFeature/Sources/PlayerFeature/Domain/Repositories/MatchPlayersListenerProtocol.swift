// MARK: - Match Players Snapshot

struct MatchPlayersSnapshot {
    let teamAPlayers: [MatchPlayer]
    let teamBPlayers: [MatchPlayer]
    /// Maps playerId → reservation expiry date (only for RESERVED players).
    let reservationsByPlayerId: [String: Date]
}

// MARK: - Match Players Listener Protocol

protocol MatchPlayersListenerProtocol {
    func playerStream(matchId: String) -> AsyncStream<MatchPlayersSnapshot>
}
