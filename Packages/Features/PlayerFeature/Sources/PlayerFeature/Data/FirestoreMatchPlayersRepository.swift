import FirebaseFirestore

// MARK: - Firestore Match Players Repository

final class FirestoreMatchPlayersRepository: MatchPlayersListenerProtocol {
    private let db = Firestore.firestore()

    func playerStream(matchId: String) -> AsyncStream<MatchPlayersSnapshot> {
        AsyncStream { continuation in
            #if DEBUG
            print("[Firestore] Subscribing to match_players/\(matchId)")
            #endif
            let listener = db.collection("match_players")
                .document(matchId)
                .addSnapshotListener { snapshot, error in
                    #if DEBUG
                    if let error {
                        print("[Firestore] Listener error: \(error)")
                        return
                    }
                    guard let snapshot else {
                        print("[Firestore] Snapshot is nil for matchId: \(matchId)")
                        return
                    }
                    guard snapshot.exists else {
                        print("[Firestore] Document does not exist for matchId: \(matchId)")
                        return
                    }
                    guard let data = snapshot.data() else {
                        print("[Firestore] snapshot.data() returned nil for matchId: \(matchId)")
                        return
                    }
                    guard let rawPlayers = data["players"] as? [[String: Any]] else {
                        print("[Firestore] 'players' field missing or wrong type. data keys: \(data.keys.joined(separator: ", "))")
                        return
                    }
                    print("[Firestore] Received \(rawPlayers.count) players for matchId: \(matchId)")
                    #else
                    guard let data = snapshot?.data(),
                          let rawPlayers = data["players"] as? [[String: Any]] else {
                        return
                    }
                    #endif

                    let players = rawPlayers.compactMap { MatchPlayerFirestoreDTO(dict: $0) }
                    let teamA = players
                        .filter { $0.team.uppercased() == "A" }
                        .map { $0.toMatchPlayer() }
                    let teamB = players
                        .filter { $0.team.uppercased() == "B" }
                        .map { $0.toMatchPlayer() }

                    var reservations: [String: Date] = [:]
                    for p in players where p.status.uppercased() == "RESERVED" {
                        if let expiry = p.reservationExpiresAt {
                            reservations[p.playerId] = expiry
                        }
                    }

                    #if DEBUG
                    print("[Firestore] Team A: \(teamA.count) players, Team B: \(teamB.count) players")
                    #endif

                    continuation.yield(MatchPlayersSnapshot(teamAPlayers: teamA, teamBPlayers: teamB, reservationsByPlayerId: reservations))
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Private DTO

private struct MatchPlayerFirestoreDTO {
    let playerId: String
    let name: String
    let avatarUrl: String?
    let team: String
    let status: String
    let country: String?
    let reservationExpiresAt: Date?

    init?(dict: [String: Any]) {
        guard let playerId = dict["playerId"] as? String,
              let name = dict["name"] as? String,
              let team = dict["team"] as? String,
              let status = dict["status"] as? String else {
            return nil
        }
        self.playerId = playerId
        self.name = name
        self.avatarUrl = dict["avatarUrl"] as? String
        self.team = team
        self.status = status
        self.country = dict["country"] as? String

        // reservationExpiresAt can be a Firestore Timestamp or a Unix ms integer
        if let ts = dict["reservationExpiresAt"] as? Timestamp {
            self.reservationExpiresAt = ts.dateValue()
        } else if let ms = dict["reservationExpiresAt"] as? Int64 {
            self.reservationExpiresAt = Date(timeIntervalSince1970: Double(ms) / 1000)
        } else if let ms = dict["reservationExpiresAt"] as? Double {
            self.reservationExpiresAt = Date(timeIntervalSince1970: ms / 1000)
        } else {
            self.reservationExpiresAt = nil
        }
    }

    func toMatchPlayer() -> MatchPlayer {
        MatchPlayer(
            id: playerId,
            playerId: playerId,
            name: name,
            avatarUrl: avatarUrl,
            status: status.uppercased() == "RESERVED" ? .reserved : .joined,
            country: country
        )
    }
}
