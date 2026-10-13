import XCTest
@testable import PlayerFeature

final class MatchTeamVisualsDTOTests: XCTestCase {

    private func detailJSON(visuals: String) -> Data {
        Data("""
        {
          "id": "m1", "fieldName": "Cancha", "startTime": 0, "endTime": 3600000,
          "originalPriceInCents": 15000, "totalDiscountInCents": 0, "priceInCents": 15000,
          "genderType": "MIXED", "status": "SCHEDULED", "availableSpots": 4,
          "teams": {
            "teamA": { "playerCount": 0, "players": [] },
            "teamB": { "playerCount": 0, "players": [] }
          }\(visuals)
        }
        """.utf8)
    }

    private func listJSON(visuals: String) -> Data {
        Data("""
        {
          "id": "m1", "fieldName": "Cancha", "startTime": 0, "endTime": 3600000,
          "originalPriceInCents": 15000, "totalDiscountInCents": 0, "priceInCents": 15000,
          "genderType": "MIXED", "status": "SCHEDULED", "maxPlayers": 10,
          "teams": {
            "teamA": { "playerCount": 0, "players": [] },
            "teamB": { "playerCount": 0, "players": [] }
          }\(visuals)
        }
        """.utf8)
    }

    private let visuals = ##", "teamVisuals": {"teamA": {"name": "All Blacks", "color": "#292D34"}, "teamB": {"name": "Red Devils", "color": "#B43C4A"}}"##

    func test_detail_mapsSnapshotNamesAndColors() throws {
        let item = try JSONDecoder().decode(MatchDetailItemDTO.self, from: detailJSON(visuals: visuals)).toMatchItem()

        XCTAssertEqual(item.teamAName, "All Blacks")
        XCTAssertEqual(item.teamBName, "Red Devils")
        XCTAssertEqual(item.teamAColorHex, "#292D34")
        XCTAssertEqual(item.teamBColorHex, "#B43C4A")
    }

    func test_v2List_mapsSnapshot() throws {
        let item = try JSONDecoder().decode(MatchListItemV2DTO.self, from: listJSON(visuals: visuals)).toMatchItem()

        XCTAssertEqual(item.teamVisuals?.teamA.name, "All Blacks")
    }

    func test_matchesWithoutSnapshot_fallBackToLocalizedNames_andNoColor() throws {
        let item = try JSONDecoder().decode(MatchDetailItemDTO.self, from: detailJSON(visuals: "")).toMatchItem()

        XCTAssertNil(item.teamVisuals)
        XCTAssertEqual(item.teamAName, L10n.Matches.teamA)
        XCTAssertEqual(item.teamBName, L10n.Matches.teamB)
        XCTAssertNil(item.teamAColorHex)
    }

    func test_blankSnapshotName_fallsBackToLocalizedName() throws {
        let blank = ##", "teamVisuals": {"teamA": {"name": "  ", "color": "#000000"}, "teamB": {"name": "Red Devils", "color": null}}"##
        let item = try JSONDecoder().decode(MatchDetailItemDTO.self, from: detailJSON(visuals: blank)).toMatchItem()

        XCTAssertEqual(item.teamAName, L10n.Matches.teamA)
        XCTAssertNil(item.teamBColorHex)
    }
}
