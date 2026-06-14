import XCTest
@testable import PlayerFeature

final class FetchMatchesUseCaseTests: XCTestCase {

    private let region = MatchRegion.default

    func test_execute_sendsStoredVersionAndRegion_andForwardsCoordinates() async throws {
        let service = MockMatchService()
        let store = MockMatchVersionStore()
        store.storage[region.key] = 7
        service.fetchMatchesV2Result = .success(
            MatchesV2Result(region: region.key, currentVersion: 8, hasChanges: true, matches: [.stub(id: "m1")])
        )
        let sut = FetchMatchesUseCase(matchService: service, versionStore: store)

        let result = try await sut.execute(region: region, lat: 19.4, lon: -99.1)

        XCTAssertEqual(service.fetchMatchesV2CallCount, 1)
        XCTAssertEqual(service.lastSinceVersion, 7)
        XCTAssertEqual(service.lastV2CountryCode, region.countryCode)
        XCTAssertEqual(service.lastV2StateCode, region.stateCode)
        XCTAssertEqual(service.lastV2Lat, 19.4)
        XCTAssertEqual(service.lastV2Lon, -99.1)
        XCTAssertEqual(result, .changed(matches: [.stub(id: "m1")], version: 8))
    }

    func test_execute_persistsNewVersion_onChange() async throws {
        let service = MockMatchService()
        let store = MockMatchVersionStore()
        service.fetchMatchesV2Result = .success(
            MatchesV2Result(region: "MX:CDMX", currentVersion: 11, hasChanges: true, matches: [.stub()])
        )
        let sut = FetchMatchesUseCase(matchService: service, versionStore: store)

        _ = try await sut.execute(region: region, lat: nil, lon: nil)

        XCTAssertEqual(store.storage["MX:CDMX"], 11)
    }

    func test_execute_returnsUnchanged_whenBackendReportsNoChanges() async throws {
        let service = MockMatchService()
        let store = MockMatchVersionStore()
        store.storage[region.key] = 10
        service.fetchMatchesV2Result = .success(
            MatchesV2Result(region: region.key, currentVersion: 10, hasChanges: false, matches: nil)
        )
        let sut = FetchMatchesUseCase(matchService: service, versionStore: store)

        let result = try await sut.execute(region: region, lat: nil, lon: nil)

        XCTAssertEqual(result, .unchanged(version: 10))
        XCTAssertEqual(store.storage[region.key], 10)
    }

    func test_execute_firstLaunch_sendsNilSinceVersion() async throws {
        let service = MockMatchService()
        let store = MockMatchVersionStore()
        service.fetchMatchesV2Result = .success(
            MatchesV2Result(region: region.key, currentVersion: 1, hasChanges: true, matches: [])
        )
        let sut = FetchMatchesUseCase(matchService: service, versionStore: store)

        _ = try await sut.execute(region: region, lat: nil, lon: nil)

        XCTAssertNil(service.lastSinceVersion)
    }

    func test_execute_propagatesServiceError() async {
        let service = MockMatchService()
        let store = MockMatchVersionStore()
        service.fetchMatchesV2Result = .failure(TestError.boom)
        let sut = FetchMatchesUseCase(matchService: service, versionStore: store)

        do {
            _ = try await sut.execute(region: region, lat: nil, lon: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
