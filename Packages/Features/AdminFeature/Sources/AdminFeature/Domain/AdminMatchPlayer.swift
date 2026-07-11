import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// MARK: - AdminMatchPlayer

/// A single player in the live match lineup, as observed from Firestore.
/// Mirrors PlayerFeature's `MatchPlayer` so the admin lineup looks identical.
struct AdminMatchPlayer: Identifiable, Hashable, Codable {
    let id: String
    let playerId: String
    let name: String
    let avatarUrl: String?
    let status: Status
    let country: String?
    /// True for walk-in / external players who are not registered in the platform.
    let isExternal: Bool

    enum Status: String, Codable {
        case joined
        case reserved
    }

    init(
        id: String = UUID().uuidString,
        playerId: String = "",
        name: String,
        avatarUrl: String? = nil,
        status: Status = .joined,
        country: String? = nil,
        isExternal: Bool = false
    ) {
        self.id = id
        self.playerId = playerId
        self.name = name
        self.avatarUrl = avatarUrl
        self.status = status
        self.country = country
        self.isExternal = isExternal
    }

    /// Flag emoji derived from an ISO-2 country code (e.g. "MX" → "🇲🇽"). Nil when unknown.
    var countryFlag: String? {
        guard let iso = country?.uppercased(),
              iso.count == 2,
              iso.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 })
        else { return nil }
        return iso.unicodeScalars.map { String(Unicode.Scalar($0.value + 127_397)!) }.joined()
    }

    static func == (lhs: AdminMatchPlayer, rhs: AdminMatchPlayer) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Snapshot

struct AdminMatchPlayersSnapshot {
    let teamAPlayers: [AdminMatchPlayer]
    let teamBPlayers: [AdminMatchPlayer]
    /// Maps playerId → reservation expiry date (only for RESERVED players).
    let reservationsByPlayerId: [String: Date]
}

// MARK: - Transferable

extension UTType {
    static let adminMatchPlayer = UTType(exportedAs: "com.futmatch.adminMatchPlayer")
}

extension AdminMatchPlayer: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .adminMatchPlayer)
    }
}

// MARK: - Listener Protocol

protocol AdminMatchPlayersListenerProtocol {
    func playerStream(matchId: String) -> AsyncThrowingStream<AdminMatchPlayersSnapshot, Error>
}
