import FirebaseFirestore

// MARK: - Firestore Admin Match Players Repository

/// Streams the live lineup for a match from Firestore (`match_players/{matchId}`).
/// Mirrors PlayerFeature's `FirestoreMatchPlayersRepository` so admin and player
/// see the same real-time roster.
final class FirestoreAdminMatchPlayersRepository: AdminMatchPlayersListenerProtocol {
    private let db = Firestore.firestore()

    func playerStream(matchId: String) -> AsyncThrowingStream<AdminMatchPlayersSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("match_players")
                .document(matchId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let data = snapshot?.data(),
                          let rawPlayers = data["players"] as? [[String: Any]] else {
                        return
                    }

                    let players = rawPlayers.compactMap { AdminMatchPlayerFirestoreDTO(dict: $0) }
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

                    continuation.yield(
                        AdminMatchPlayersSnapshot(
                            teamAPlayers: teamA,
                            teamBPlayers: teamB,
                            reservationsByPlayerId: reservations
                        )
                    )
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Private DTO

private struct AdminMatchPlayerFirestoreDTO {
    let playerId: String
    let name: String
    let avatarUrl: String?
    let team: String
    let status: String
    let country: String?
    let reservationExpiresAt: Date?
    let isExternal: Bool

    init?(dict: [String: Any]) {
        guard let playerId = dict["playerId"] as? String,
              let team = dict["team"] as? String,
              let status = dict["status"] as? String else {
            return nil
        }
        self.playerId = playerId
        let rawName = dict["name"] as? String
        self.isExternal = dict["isExternal"] as? Bool ?? (rawName == nil || rawName?.isEmpty == true)
        self.name = rawName?.isEmpty == false ? rawName! : ""
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

    func toMatchPlayer() -> AdminMatchPlayer {
        AdminMatchPlayer(
            id: playerId,
            playerId: playerId,
            name: name,
            avatarUrl: avatarUrl,
            status: status.uppercased() == "RESERVED" ? .reserved : .joined,
            country: country,
            isExternal: isExternal
        )
    }
}
