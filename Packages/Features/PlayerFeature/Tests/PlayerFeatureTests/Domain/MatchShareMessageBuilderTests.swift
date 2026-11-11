import XCTest
@testable import PlayerFeature

final class MatchShareMessageBuilderTests: XCTestCase {

    private let url = URL(string: "https://interfut.app/matches/123e4567-e89b-12d3-a456-426614174000")!
    private let sut = MatchShareMessageBuilder()

    func test_message_includesMatchDataAndEndsWithLink() {
        let match = MatchItem(
            venueName: "La Jaula",
            location: "Calzada Casa del Obrero Mundial, CDMX",
            timeRange: "08:00 PM - 09:00 PM",
            date: "Sáb, 14 nov",
            price: "$160.00 MXN",
            matchType: "Mixto",
            spotsLeft: 10
        )

        let message = sut.message(for: match, url: url)
        let lines = message.components(separatedBy: "\n")

        XCTAssertTrue(message.contains("La Jaula"))
        XCTAssertTrue(message.contains("Sáb, 14 nov · 08:00 PM - 09:00 PM"))
        XCTAssertTrue(message.contains("$160.00 MXN"))
        XCTAssertTrue(message.contains("Calzada Casa del Obrero Mundial, CDMX"))
        XCTAssertEqual(lines.first, L10n.MatchDetail.shareInvite)
        XCTAssertEqual(lines.last, url.absoluteString)
        XCTAssertEqual(lines.count, 6)
    }

    func test_message_skipsEmptyFields() {
        let match = MatchItem(
            venueName: "La Jaula",
            location: "  ",
            timeRange: "08:00 PM - 09:00 PM",
            date: "",
            price: "",
            matchType: "Mixto",
            spotsLeft: 10
        )

        let lines = sut.message(for: match, url: url).components(separatedBy: "\n")

        // Invite, field, time, link — no price or location line, no empty date part.
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[2].hasSuffix("08:00 PM - 09:00 PM"))
        XCTAssertFalse(lines[2].contains("·"))
    }
}
