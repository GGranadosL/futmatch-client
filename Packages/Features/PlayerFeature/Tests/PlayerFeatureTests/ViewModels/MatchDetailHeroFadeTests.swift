import XCTest
@testable import PlayerFeature

final class MatchDetailHeroFadeTests: XCTestCase {

    func test_progress_followsScrollAndClamps() {
        let distance = MatchDetailHeroFade.distance
        XCTAssertEqual(MatchDetailHeroFade.progress(forOffset: -40), 0)   // pulling down
        XCTAssertEqual(MatchDetailHeroFade.progress(forOffset: 0), 0)
        XCTAssertEqual(MatchDetailHeroFade.progress(forOffset: distance / 2), 0.5, accuracy: 0.0001)
        XCTAssertEqual(MatchDetailHeroFade.progress(forOffset: distance * 3), 1)
    }

    func test_title_appearsOnlyNearTheEnd() {
        XCTAssertEqual(MatchDetailHeroFade.titleOpacity(forProgress: 0.5), 0)
        XCTAssertEqual(MatchDetailHeroFade.titleOpacity(forProgress: MatchDetailHeroFade.titleStart), 0)
        XCTAssertEqual(MatchDetailHeroFade.titleOpacity(forProgress: 0.8), 0.5, accuracy: 0.0001)
        XCTAssertEqual(MatchDetailHeroFade.titleOpacity(forProgress: 1), 1)
    }

    func test_state_measuresFromFirstPosition_andReverses() {
        let state = MatchDetailHeroScrollState()
        let distance = MatchDetailHeroFade.distance

        state.update(contentTop: 20)                 // resting position isn't always 0
        XCTAssertEqual(state.progress, 0)

        state.update(contentTop: 20 - distance / 2)  // scrolled halfway
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.0001)

        state.update(contentTop: 20)                 // back to the top
        XCTAssertEqual(state.progress, 0)
    }
}
