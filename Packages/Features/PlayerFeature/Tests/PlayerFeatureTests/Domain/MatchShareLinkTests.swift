import XCTest
@testable import PlayerFeature

final class MatchShareLinkTests: XCTestCase {

    private let id = "123e4567-e89b-12d3-a456-426614174000"

    // MARK: - Building

    func test_url_buildsCanonicalLink() {
        XCTAssertEqual(
            MatchShareLink.url(forMatchId: id)?.absoluteString,
            "https://interfut.app/matches/\(id)"
        )
    }

    func test_url_rejectsNonUUIDIds() {
        XCTAssertNil(MatchShareLink.url(forMatchId: "match-1"))
        XCTAssertNil(MatchShareLink.url(forMatchId: "../admin"))
        XCTAssertNil(MatchShareLink.url(forMatchId: ""))
    }

    func test_builtLink_roundTripsToSameId() throws {
        let url = try XCTUnwrap(MatchShareLink.url(forMatchId: id))
        XCTAssertEqual(MatchShareLink.matchId(from: url), id)
    }

    // MARK: - Parsing

    func test_matchId_acceptsCanonicalLink() {
        XCTAssertEqual(parse("https://interfut.app/matches/\(id)"), id)
    }

    func test_matchId_ignoresQueryFragmentAndTrailingSlash() {
        XCTAssertEqual(parse("https://interfut.app/matches/\(id)?utm_source=whatsapp"), id)
        XCTAssertEqual(parse("https://interfut.app/matches/\(id)#top"), id)
        XCTAssertEqual(parse("https://interfut.app/matches/\(id)/"), id)
    }

    func test_matchId_rejectsOtherHostsAndSchemes() {
        XCTAssertNil(parse("http://interfut.app/matches/\(id)"))
        XCTAssertNil(parse("https://evil.com/matches/\(id)"))
        XCTAssertNil(parse("https://interfut.app.evil.com/matches/\(id)"))
        XCTAssertNil(parse("https://www.interfut.app/matches/\(id)"))
        XCTAssertNil(parse("https://interfut.app:8443/matches/\(id)"))
        XCTAssertNil(parse("https://user@interfut.app/matches/\(id)"))
    }

    func test_matchId_rejectsOtherPaths() {
        XCTAssertNil(parse("https://interfut.app/"))
        XCTAssertNil(parse("https://interfut.app/matches"))
        XCTAssertNil(parse("https://interfut.app/matches/not-a-uuid"))
        XCTAssertNil(parse("https://interfut.app/matches/\(id)/join"))
        XCTAssertNil(parse("https://interfut.app/fields/\(id)"))
        XCTAssertNil(parse("https://interfut.app/api/matches/\(id)"))
    }

    private func parse(_ string: String) -> String? {
        URL(string: string).flatMap(MatchShareLink.matchId(from:))
    }
}
