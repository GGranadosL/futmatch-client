import XCTest
@testable import AdminFeature

final class MatchTeamVisualsDTOTests: XCTestCase {

    private func listItemJSON(visuals: String) -> Data {
        Data("""
        {
          "matchId": "m1", "fieldId": "f1", "fieldName": "Cancha",
          "matchDateTime": 0, "matchDateTimeEnd": 3600000,
          "matchPriceInCents": 15000, "discountInCents": 0,
          "maxPlayers": 10, "enrolledPlayers": 4, "minPlayersRequired": 6,
          "status": "SCHEDULED", "fieldImages": [],
          "genderType": "MIXED", "playerLevel": "ANY"\(visuals)
        }
        """.utf8)
    }

    func test_toDomain_mapsTeamVisualsSnapshot() throws {
        let json = listItemJSON(visuals: ##", "teamVisuals": {"teamA": {"name": "Les Bleus", "color": "#315DA8"}, "teamB": {"name": "Red Devils", "color": "#B43C4A"}}"##)

        let match = try JSONDecoder().decode(AdminMatchListItemDTO.self, from: json).toDomain()

        XCTAssertEqual(match.teamVisuals?.teamA, AdminMatchTeamVisual(name: "Les Bleus", colorHex: "#315DA8"))
        XCTAssertEqual(match.teamVisuals?.teamB.name, "Red Devils")
    }

    func test_toDomain_leavesVisualsNil_forMatchesCreatedBeforeTheFeature() throws {
        let match = try JSONDecoder().decode(AdminMatchListItemDTO.self, from: listItemJSON(visuals: "")).toDomain()

        XCTAssertNil(match.teamVisuals)
    }

    func test_requests_omitTeamIds_whenNotProvided() throws {
        let params = UpdateMatchParams(
            matchId: "m1", fieldId: "f1", fieldName: "Cancha", date: Date(), startTime: Date(), endTime: Date(),
            minPlayers: 6, maxPlayers: 10, priceInCents: 15000, gender: .mixed, playerLevel: .any
        )

        let data = try JSONEncoder().encode(UpdateMatchRequestDTO.from(params))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["teamAId"])
        XCTAssertNil(object["teamBId"])
    }
}
