import XCTest
@testable import PlayerFeature

/// Guest mode: browsing matches without an account (App Store 5.1.1(v)).
final class GuestMatchTests: XCTestCase {

    // MARK: - Endpoints

    func test_guestEndpoints_useUnauthenticatedPublicRoutes() {
        let feed = MatchEndpoint.guestMatchesV2(sinceVersion: 7, countryCode: "MX", stateCode: "CDMX", lat: nil, lon: nil)
        XCTAssertEqual(feed.path, "/guest/match/matches/v2")
        XCTAssertEqual(feed.method, .get)
        XCTAssertEqual(
            feed.queryItems,
            [
                URLQueryItem(name: "sinceVersion", value: "7"),
                URLQueryItem(name: "countryCode", value: "MX"),
                URLQueryItem(name: "stateCode", value: "CDMX")
            ]
        )

        XCTAssertEqual(MatchEndpoint.guestMatchDetail(id: "abc").path, "/guest/match/abc")
    }

    func test_authenticatedEndpoints_areUnchanged() {
        XCTAssertEqual(
            MatchEndpoint.matchesV2(sinceVersion: nil, countryCode: nil, stateCode: nil, lat: nil, lon: nil).path,
            "/match/matches/v2"
        )
        XCTAssertEqual(MatchEndpoint.matchDetail(id: "abc").path, "/match/abc")
    }

    // MARK: - Occupancy without a roster

    func test_playerCount_usesBackendCount_whenRosterIsHidden() {
        let match = MatchItem(
            venueName: "Cancha",
            timeRange: "",
            price: "",
            matchType: "",
            spotsLeft: 7,
            teamAPlayers: [],
            teamBPlayers: [],
            teamAOccupiedCount: 2,
            teamBOccupiedCount: 1
        )

        XCTAssertEqual(match.teamAPlayerCount, 2)
        XCTAssertEqual(match.teamBPlayerCount, 1)
    }

    func test_playerCount_fallsBackToRoster_whenNoBackendCount() {
        let match = MatchItem(
            venueName: "Cancha",
            timeRange: "",
            price: "",
            matchType: "",
            spotsLeft: 9,
            teamAPlayers: [MatchPlayer(name: "Jugador")]
        )

        XCTAssertEqual(match.teamAPlayerCount, 1)
        XCTAssertEqual(match.teamBPlayerCount, 0)
    }
}
