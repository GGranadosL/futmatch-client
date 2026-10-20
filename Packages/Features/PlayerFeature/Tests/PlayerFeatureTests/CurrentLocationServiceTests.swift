import XCTest
import CoreLocation
@testable import PlayerFeature

// MARK: - Mocks

@MainActor
private final class MockLocationManager: LocationManaging {
    var authorizationStatus: CLAuthorizationStatus
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationResult: ((CLLocationCoordinate2D?) -> Void)?
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() { authorizationRequestCount += 1 }
    func requestLocation() { locationRequestCount += 1 }

    func simulateAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        onAuthorizationChange?(status)
    }

    func simulateFix(_ coordinate: CLLocationCoordinate2D) { onLocationResult?(coordinate) }
    func simulateFailure() { onLocationResult?(nil) }
}

private let fix = CLLocationCoordinate2D(latitude: 20.6597, longitude: -103.3496)

// MARK: - CurrentLocationService

@MainActor
final class CurrentLocationServiceTests: XCTestCase {

    private func makeSUT(
        status: CLAuthorizationStatus,
        authorizationTimeout: UInt64 = 5_000_000_000,
        fixTimeout: UInt64 = 5_000_000_000
    ) -> (CurrentLocationService, MockLocationManager) {
        let manager = MockLocationManager(authorizationStatus: status)
        let sut = CurrentLocationService(
            makeLocationManager: { manager },
            authorizationTimeoutNanoseconds: authorizationTimeout,
            fixTimeoutNanoseconds: fixTimeout
        )
        return (sut, manager)
    }

    /// Lets tasks started on the main actor reach their suspension point.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition(), "condition never became true")
    }

    func test_denied_returnsNilWithoutPrompting() async {
        let (sut, manager) = makeSUT(status: .denied)
        let result = await sut.requestCurrentLocation()
        XCTAssertNil(result)
        XCTAssertEqual(manager.authorizationRequestCount, 0)
        XCTAssertEqual(manager.locationRequestCount, 0)
    }

    func test_restricted_returnsNilWithoutPrompting() async {
        let (sut, manager) = makeSUT(status: .restricted)
        let result = await sut.requestCurrentLocation()
        XCTAssertNil(result)
        XCTAssertEqual(manager.locationRequestCount, 0)
    }

    func test_authorized_returnsFix() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }

        manager.simulateFix(fix)

        let result = await request.value
        XCTAssertEqual(result?.latitude, fix.latitude)
        XCTAssertEqual(result?.longitude, fix.longitude)
        XCTAssertEqual(manager.authorizationRequestCount, 0)
    }

    func test_authorized_failure_returnsNil() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }

        manager.simulateFailure()

        let result = await request.value
        XCTAssertNil(result)
    }

    /// The TestFlight crash: a fix, a failure, an authorization change and the
    /// timeout all trying to finish the same request. Resuming the continuation
    /// twice traps, so this test crashing the runner is the regression signal.
    func test_duplicateCallbacksAfterFinish_resumeOnlyOnce() async throws {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse, fixTimeout: 50_000_000)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }

        manager.simulateFix(fix)
        manager.simulateFix(fix)
        manager.simulateFailure()
        manager.simulateAuthorization(.denied)

        let result = await request.value
        XCTAssertEqual(result?.latitude, fix.latitude)

        // Outlive the (cancelled) timeout so a stray finish would have fired.
        try await Task.sleep(nanoseconds: 150_000_000)
    }

    func test_authorizationCallbackOnCreation_doesNotRequestASecondFix() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }

        // CoreLocation reports the current status when the manager is created.
        manager.simulateAuthorization(.authorizedWhenInUse)
        XCTAssertEqual(manager.locationRequestCount, 1)

        manager.simulateFix(fix)
        _ = await request.value
    }

    func test_concurrentRequests_shareOneFix() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let first = Task { await sut.requestCurrentLocation() }
        let second = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }
        // Give the second caller time to join the pending request.
        for _ in 0..<50 { await Task.yield() }

        manager.simulateFix(fix)

        let results = await [first.value, second.value]
        XCTAssertEqual(results.compactMap { $0?.latitude }, [fix.latitude, fix.latitude])
        XCTAssertEqual(manager.locationRequestCount, 1)
    }

    func test_notDetermined_promptsThenResolvesAfterGrant() async {
        let (sut, manager) = makeSUT(status: .notDetermined)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.authorizationRequestCount == 1 }
        XCTAssertEqual(manager.locationRequestCount, 0)

        manager.simulateAuthorization(.authorizedWhenInUse)
        XCTAssertEqual(manager.locationRequestCount, 1)
        manager.simulateFix(fix)

        let result = await request.value
        XCTAssertEqual(result?.latitude, fix.latitude)
    }

    func test_notDetermined_deniedInDialog_returnsNil() async {
        let (sut, manager) = makeSUT(status: .notDetermined)
        let request = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.authorizationRequestCount == 1 }

        manager.simulateAuthorization(.denied)

        let result = await request.value
        XCTAssertNil(result)
        XCTAssertEqual(manager.locationRequestCount, 0)
    }

    func test_notDetermined_dialogNeverAnswered_timesOut() async {
        let (sut, _) = makeSUT(status: .notDetermined, authorizationTimeout: 50_000_000)
        let result = await sut.requestCurrentLocation()
        XCTAssertNil(result)
    }

    func test_noFix_timesOutThenLateFixIsIgnored() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse, fixTimeout: 50_000_000)
        let result = await sut.requestCurrentLocation()
        XCTAssertNil(result)

        // A fix arriving after the timeout has nobody to resume.
        manager.simulateFix(fix)
    }

    func test_newRequestAfterTimeout_requestsAFreshFix() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse, fixTimeout: 50_000_000)
        _ = await sut.requestCurrentLocation()
        XCTAssertEqual(manager.locationRequestCount, 1)

        let retry = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 2 }
        manager.simulateFix(fix)

        let result = await retry.value
        XCTAssertEqual(result?.latitude, fix.latitude)
    }

    func test_successfulFix_isCachedForLaterCallers() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let first = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }
        manager.simulateFix(fix)
        _ = await first.value

        let cached = await sut.requestCurrentLocation()
        XCTAssertEqual(cached?.latitude, fix.latitude)
        XCTAssertEqual(manager.locationRequestCount, 1)
    }

    func test_failedFix_isNotCached() async {
        let (sut, manager) = makeSUT(status: .authorizedWhenInUse)
        let first = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 1 }
        manager.simulateFailure()
        _ = await first.value

        let retry = Task { await sut.requestCurrentLocation() }
        await waitUntil { manager.locationRequestCount == 2 }
        manager.simulateFix(fix)
        let result = await retry.value
        XCTAssertEqual(result?.latitude, fix.latitude)
    }
}
