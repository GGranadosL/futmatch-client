import XCTest
@testable import PlayerFeature

final class ProfileCollapseModelTests: XCTestCase {

    private func model(scrollOffset: CGFloat = 0, withEnds: Bool = true) -> ProfileCollapseModel {
        var frames: [ProfileAnchor: CGRect] = [
            .avatarStart: CGRect(x: 129, y: 120, width: 132, height: 132),
            .nameStart: CGRect(x: 100, y: 300, width: 190, height: 30)
        ]
        if withEnds {
            frames[.avatarEnd] = CGRect(x: 16, y: 60, width: 32, height: 32)
            frames[.nameEnd] = CGRect(x: 58, y: 100, width: 120, height: 20)
        }
        return ProfileCollapseModel(frames: frames, scrollOffset: scrollOffset)
    }

    func test_isReady_onlyWhenAllFourAnchorsAreMeasured() {
        XCTAssertTrue(model().isReady)
        XCTAssertFalse(model(withEnds: false).isReady)
    }

    func test_progress_isZeroAtRest_andOneOnceTheNameReachedTheBar() {
        // The name travels from y 300 to y 100.
        XCTAssertEqual(model(scrollOffset: 0).progress, 0)
        XCTAssertEqual(model(scrollOffset: 100).progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(model(scrollOffset: 200).progress, 1)
        XCTAssertEqual(model(scrollOffset: 900).progress, 1, "Scrolling further must not overshoot")
    }

    func test_progress_isZeroWhileOverscrolling() {
        XCTAssertEqual(model(scrollOffset: -80).progress, 0)
    }

    func test_progress_isZeroUntilAnchorsAreMeasured() {
        XCTAssertEqual(model(scrollOffset: 100, withEnds: false).progress, 0)
    }

    func test_avatarArrivesBeforeTheName() {
        let halfway = model(scrollOffset: 100)
        XCTAssertGreaterThan(halfway.avatarProgress, halfway.progress)
        XCTAssertEqual(model(scrollOffset: 200).avatarProgress, 1)
    }

    func test_frames_matchTheStartAnchorsAtRest_andTheEndAnchorsWhenCollapsed() {
        XCTAssertEqual(model(scrollOffset: 0).avatarFrame, CGRect(x: 129, y: 120, width: 132, height: 132))
        XCTAssertEqual(model(scrollOffset: 0).nameFrame, CGRect(x: 100, y: 300, width: 190, height: 30))
        XCTAssertEqual(model(scrollOffset: 200).avatarFrame, CGRect(x: 16, y: 60, width: 32, height: 32))
        XCTAssertEqual(model(scrollOffset: 200).nameFrame, CGRect(x: 58, y: 100, width: 120, height: 20))
    }

    func test_nameFollowsTheScroll_linearly() {
        // Content moved up by 50pt, so the name sits 50pt higher than at rest.
        XCTAssertEqual(model(scrollOffset: 50).nameFrame?.minY ?? 0, 250, accuracy: 0.0001)
    }

    func test_identityFollowsTheContentDown_whenOverscrolling() {
        XCTAssertEqual(model(scrollOffset: -40).nameFrame?.minY ?? 0, 340, accuracy: 0.0001)
        XCTAssertEqual(model(scrollOffset: -40).avatarFrame?.minY ?? 0, 160, accuracy: 0.0001)
    }
}
