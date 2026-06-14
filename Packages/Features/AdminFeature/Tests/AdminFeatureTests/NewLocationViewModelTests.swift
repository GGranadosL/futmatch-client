import XCTest
import CoreLocation
@testable import AdminFeature

// MARK: - Mocks

private final class MockLocationCatalogRepository: LocationCatalogRepositoryProtocol {
    var stubbedCatalog: [AdminLocationCountry] = []
    func fetchCatalog() async -> [AdminLocationCountry] { stubbedCatalog }
}

private final class MockCurrentLocationProvider: CurrentLocationProviding {
    var stubbedCoordinate: CLLocationCoordinate2D?
    func requestCurrentLocation() async -> CLLocationCoordinate2D? { stubbedCoordinate }
}

private final class MockGeocodingService: GeocodingServiceProtocol {
    var stubbedAddress = "Calle Falsa 123"
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String { stubbedAddress }
    func searchAddresses(query: String) async throws -> [GeocodingSearchResult] { [] }
}

private final class MockCreateLocationUseCase: CreateLocationUseCaseProtocol {
    func execute(request: CreateLocationRequest) async throws -> AdminLocation {
        AdminLocation(id: "1", address: request.address, country: request.countryCode,
                      city: request.cityCode, latitude: request.latitude, longitude: request.longitude)
    }
}

// MARK: - FetchLocationCatalogUseCase

final class FetchLocationCatalogUseCaseTests: XCTestCase {

    func test_execute_returnsRemoteCatalog() async {
        let repo = MockLocationCatalogRepository()
        repo.stubbedCatalog = [
            AdminLocationCountry(code: "MX", name: "México",
                                 cities: [AdminLocationCity(code: "MX_CDMX", name: "Ciudad de México")])
        ]
        let sut = FetchLocationCatalogUseCase(repository: repo)

        let result = await sut.execute()

        XCTAssertEqual(result, repo.stubbedCatalog)
    }

    func test_execute_emptyCatalog_returnsEnumFallback() async {
        let repo = MockLocationCatalogRepository()
        let sut = FetchLocationCatalogUseCase(repository: repo)

        let result = await sut.execute()

        XCTAssertEqual(result.map(\.code), [LocationCountry.mexico.rawValue])
        XCTAssertEqual(result.first?.cities.map(\.code), [LocationCity.cdmx.rawValue])
    }
}

// MARK: - NewLocationViewModel

@MainActor
final class NewLocationViewModelTests: XCTestCase {

    private func makeSUT(
        catalog: [AdminLocationCountry] = [],
        coordinate: CLLocationCoordinate2D? = nil
    ) -> NewLocationViewModel {
        let catalogRepo = MockLocationCatalogRepository()
        catalogRepo.stubbedCatalog = catalog
        let locationProvider = MockCurrentLocationProvider()
        locationProvider.stubbedCoordinate = coordinate
        return NewLocationViewModel(
            geocodingService: MockGeocodingService(),
            createLocationUseCase: MockCreateLocationUseCase(),
            fetchCatalogUseCase: FetchLocationCatalogUseCase(repository: catalogRepo),
            currentLocationProvider: locationProvider
        )
    }

    func test_defaults_areMexicoCDMX() {
        let sut = makeSUT()
        XCTAssertEqual(sut.selectedCountry, "MX")
        XCTAssertEqual(sut.selectedCity, "MX_CDMX")
        XCTAssertEqual(sut.catalog.map(\.code), ["MX"])
    }

    func test_onAppear_remoteCatalogReplacesFallback() async {
        let remote = [
            AdminLocationCountry(code: "MX", name: "México", cities: [
                AdminLocationCity(code: "MX_CDMX", name: "Ciudad de México"),
                AdminLocationCity(code: "MX_JAL", name: "Jalisco"),
            ])
        ]
        let sut = makeSUT(catalog: remote)

        await sut.onAppear()

        XCTAssertEqual(sut.catalog, remote)
        XCTAssertEqual(sut.citiesForSelectedCountry.map(\.code), ["MX_CDMX", "MX_JAL"])
        // Existing valid selection is preserved.
        XCTAssertEqual(sut.selectedCity, "MX_CDMX")
    }

    func test_onAppear_selectionRevalidatedAgainstRemoteCatalog() async {
        let remote = [
            AdminLocationCountry(code: "AR", name: "Argentina", cities: [
                AdminLocationCity(code: "AR_BA", name: "Buenos Aires"),
            ])
        ]
        let sut = makeSUT(catalog: remote)

        await sut.onAppear()

        XCTAssertEqual(sut.selectedCountry, "AR")
        XCTAssertEqual(sut.selectedCity, "AR_BA")
    }

    func test_selectCountry_resetsCityWhenNotAvailable() async {
        let remote = [
            AdminLocationCountry(code: "MX", name: "México", cities: [
                AdminLocationCity(code: "MX_CDMX", name: "Ciudad de México"),
            ]),
            AdminLocationCountry(code: "AR", name: "Argentina", cities: [
                AdminLocationCity(code: "AR_BA", name: "Buenos Aires"),
            ]),
        ]
        let sut = makeSUT(catalog: remote)
        await sut.onAppear()

        sut.selectCountry("AR")

        XCTAssertEqual(sut.selectedCity, "AR_BA")
    }

    func test_onAppear_pinStartsAtCurrentLocation() async {
        let coordinate = CLLocationCoordinate2D(latitude: 20.65, longitude: -103.35)
        let sut = makeSUT(coordinate: coordinate)

        await sut.onAppear()

        XCTAssertEqual(sut.latitude, coordinate.latitude)
        XCTAssertEqual(sut.longitude, coordinate.longitude)
        XCTAssertEqual(sut.mapRegion.center.latitude, coordinate.latitude)
        XCTAssertEqual(sut.address, "Calle Falsa 123")
    }

    func test_onAppear_locationDenied_keepsDefaultPin() async {
        let sut = makeSUT(coordinate: nil)

        await sut.onAppear()

        XCTAssertEqual(sut.latitude, 19.4326, accuracy: 0.0001)
        XCTAssertEqual(sut.longitude, -99.1332, accuracy: 0.0001)
    }

    func test_onAppear_userAdjustedPin_isNotOverriddenByDeviceLocation() async {
        let coordinate = CLLocationCoordinate2D(latitude: 20.65, longitude: -103.35)
        let sut = makeSUT(coordinate: coordinate)

        // User taps the map before the device location resolves.
        sut.updateMapCoordinates(latitude: 25.0, longitude: -100.0)
        await sut.onAppear()

        XCTAssertEqual(sut.latitude, 25.0)
        XCTAssertEqual(sut.longitude, -100.0)
    }
}
