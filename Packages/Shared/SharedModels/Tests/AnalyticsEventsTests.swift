import XCTest
import NetworkFramework
@testable import SharedModels

final class AnalyticsEventsTests: XCTestCase {
    func test_joinStarted_alwaysCarriesTeam_andUsesLiteralValues() {
        let event = MatchEvents.joinStarted(matchId: "m1", source: .booked, team: AnalyticsTeam(apiTeam: nil))
        XCTAssertEqual(event.name, "match_join_started")
        XCTAssertEqual(event.parameters, [
            "match_id": .string("m1"), "source": .string("booked"), "team": .string("none")
        ])
    }

    func test_team_mapsApiStringsToContractValues() {
        XCTAssertEqual(AnalyticsTeam(apiTeam: "A"), .a)
        XCTAssertEqual(AnalyticsTeam(apiTeam: "B"), .b)
        XCTAssertEqual(AnalyticsTeam(apiTeam: nil), .none)
    }

    func test_booleans_areNormalisedToIntegers() {
        XCTAssertEqual(MatchEvents.joinSuccess(matchId: "m", reusedPayment: true).parameters["reused_payment"], .int(1))
        XCTAssertEqual(MatchEvents.leaveSuccess(matchId: "m", expired: false).parameters["expired"], .int(0))
    }

    func test_signupStep_usesStableLabelsAndNames() {
        let expected = [(1, "ONE", "Personal Info"), (2, "TWO", "Contact"),
                        (3, "THREE", "Football Profile"), (4, "CONFIRMATION", "Confirmation")]
        for (step, label, name) in expected {
            let event = SignUpEvents.stepCompleted(step: step, method: .email)
            XCTAssertEqual(event?.parameters["step_label"], .string(label))
            XCTAssertEqual(event?.parameters["step_name"], .string(name))
        }
        XCTAssertNil(SignUpEvents.stepCompleted(step: 5, method: .email))
    }

    func test_errorCode_prefersBackendCode_thenStatus_thenCategory() {
        let withCode = APIError.serverError(statusCode: 400, title: "t", message: "m", errorCode: "BAD_THING")
        let withoutCode = APIError.serverError(statusCode: 500, title: "t", message: "m", errorCode: "")
        XCTAssertEqual(AnalyticsErrorCode.from(withCode), "BAD_THING")
        XCTAssertEqual(AnalyticsErrorCode.from(withoutCode), "http_500")
        XCTAssertEqual(AnalyticsErrorCode.from(APIError.unauthorized), "http_401")
        XCTAssertEqual(AnalyticsErrorCode.from(APIError.networkError(URLError(.notConnectedToInternet))), "network")
        XCTAssertEqual(AnalyticsErrorCode.from(NSError(domain: "x", code: 1)), "UNKNOWN")
    }

    func test_errorCode_neverLeaksMessageText() {
        let error = APIError.serverError(statusCode: 400, title: "secret@mail.com", message: "secret", errorCode: "")
        XCTAssertFalse(AnalyticsErrorCode.from(error).contains("secret"))
    }
}

final class AnalyticsRegistryTests: XCTestCase {
    private final class Spy: AnalyticsTracking {
        var names: [String] = []
        func log(_ event: AnalyticsEvent) { names.append(event.name) }
    }

    func test_current_takenBeforeConfigure_stillReachesTheTrackerRegisteredLater() {
        let early = AnalyticsRegistry.current
        let spy = Spy()
        AnalyticsRegistry.configure(spy)
        defer { AnalyticsRegistry.configure(NoOpAnalytics()) }

        early.log(AuthEvents.loginStarted(.email))

        XCTAssertEqual(spy.names, ["login_started"])
    }
}
