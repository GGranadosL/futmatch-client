import XCTest
@testable import PlayerFeature

// MARK: - MatchDetailItemDTOTests

/// Capacity contract: per-team capacity comes from the fixed `maxPlayers` when
/// the backend sends it, so it stays stable no matter how the roster moves.
final class MatchDetailItemDTOTests: XCTestCase {

    private func decode(json: String) throws -> MatchDetailItemDTO {
        try JSONDecoder().decode(MatchDetailItemDTO.self, from: Data(json.utf8))
    }

    private func payload(maxPlayers: Int?, availableSpots: Int, teamACount: Int, teamBCount: Int) -> String {
        func players(_ prefix: String, _ count: Int) -> String {
            (0..<count)
                .map { #"{"id":"\#(prefix)\#($0)","name":"P","status":"JOINED"}"# }
                .joined(separator: ",")
        }
        let maxField = maxPlayers.map { #""maxPlayers":\#($0),"# } ?? ""
        return """
        {
          "id": "m1",
          "fieldName": "Cancha Central",
          "startTime": 0,
          "endTime": 3600000,
          "originalPriceInCents": 15000,
          "totalDiscountInCents": 0,
          "priceInCents": 15000,
          "genderType": "MIXED",
          "status": "SCHEDULED",
          \(maxField)
          "availableSpots": \(availableSpots),
          "teams": {
            "teamA": { "playerCount": \(teamACount), "players": [\(players("a", teamACount))] },
            "teamB": { "playerCount": \(teamBCount), "players": [\(players("b", teamBCount))] }
          }
        }
        """
    }

    func test_toMatchItem_prefersMaxPlayers_overAvailableSpotsSnapshot() throws {
        // Backend counter is stale/inconsistent with the roster (availableSpots
        // says 0 but only 9 players are listed). `maxPlayers` must win.
        let dto = try decode(json: payload(maxPlayers: 10, availableSpots: 0, teamACount: 4, teamBCount: 5))

        let item = dto.toMatchItem()

        XCTAssertEqual(item.teamAMax, 5)
        XCTAssertEqual(item.teamBMax, 5)
    }

    func test_toMatchItem_capacityIsStable_asRosterShrinks() throws {
        let full = try decode(json: payload(maxPlayers: 10, availableSpots: 0, teamACount: 5, teamBCount: 5))
        let afterLeave = try decode(json: payload(maxPlayers: 10, availableSpots: 1, teamACount: 4, teamBCount: 5))

        XCTAssertEqual(full.toMatchItem().teamAMax, afterLeave.toMatchItem().teamAMax)
        XCTAssertEqual(full.toMatchItem().teamBMax, afterLeave.toMatchItem().teamBMax)
    }

    func test_toMatchItem_withoutMaxPlayers_fallsBackToAvailableSpotsPlusRoster() throws {
        let dto = try decode(json: payload(maxPlayers: nil, availableSpots: 2, teamACount: 4, teamBCount: 4))

        let item = dto.toMatchItem()

        XCTAssertEqual(item.teamAMax, 5, "(2 available + 8 players) / 2")
        XCTAssertEqual(item.teamBMax, 5)
    }
}
