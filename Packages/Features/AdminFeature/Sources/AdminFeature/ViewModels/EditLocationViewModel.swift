import Foundation
import MapKit

// MARK: - Edit Location ViewModel

@MainActor
public final class EditLocationViewModel: ObservableObject {

    // MARK: - Published

    @Published public var selectedCountry: String
    @Published public var selectedCity: String
    @Published public private(set) var catalog: [AdminLocationCountry] = .fallback
    @Published public var address: String
    @Published public var latitude: Double
    @Published public var longitude: Double
    @Published public var isSaving = false
    @Published public var errorMessage: String?
    @Published public var searchQuery = ""
    @Published public var searchResults: [GeocodingSearchResult] = []
    @Published public var isSearching = false
    @Published public var mapRegion: MKCoordinateRegion
    @Published public private(set) var updatedLocation: AdminLocation?
    @Published public var cityValidationError: String?

    public var isReadyToSave: Bool {
        !address.isEmpty && cityValidationError == nil
    }

    // MARK: - Private

    private let locationId: String
    private let geocodingService: GeocodingServiceProtocol
    private let updateLocationUseCase: UpdateLocationUseCaseProtocol
    private let fetchCatalogUseCase: FetchLocationCatalogUseCaseProtocol
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        location: AdminLocation,
        geocodingService: GeocodingServiceProtocol,
        updateLocationUseCase: UpdateLocationUseCaseProtocol,
        fetchCatalogUseCase: FetchLocationCatalogUseCaseProtocol
    ) {
        self.locationId = location.id
        self.selectedCountry = location.country
        self.selectedCity = location.city
        self.address = location.address
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        self.geocodingService = geocodingService
        self.updateLocationUseCase = updateLocationUseCase
        self.fetchCatalogUseCase = fetchCatalogUseCase
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        await loadCatalog()
    }

    // MARK: - Catalog

    public var citiesForSelectedCountry: [AdminLocationCity] {
        catalog.first(where: { $0.code == selectedCountry })?.cities ?? []
    }

    public var selectedCountryName: String {
        catalog.first(where: { $0.code == selectedCountry })?.name ?? selectedCountry
    }

    public var selectedCityName: String {
        citiesForSelectedCountry.first(where: { $0.code == selectedCity })?.name ?? selectedCity
    }

    public func selectCountry(_ code: String) {
        selectedCountry = code
        if !citiesForSelectedCountry.contains(where: { $0.code == selectedCity }) {
            selectCity(citiesForSelectedCountry.first?.code ?? selectedCity)
        }
    }

    public func selectCity(_ code: String) {
        selectedCity = code
        cityValidationError = nil
        address = ""

        guard let city = LocationCity(rawValue: code) else { return }
        let center = CLLocationCoordinate2D(latitude: city.centerLatitude, longitude: city.centerLongitude)
        latitude = city.centerLatitude
        longitude = city.centerLongitude
        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: city.mapSpanDelta, longitudeDelta: city.mapSpanDelta)
        )
    }

    private func loadCatalog() async {
        let countries = await fetchCatalogUseCase.execute()
        guard !countries.isEmpty else { return }
        catalog = countries
        if !countries.contains(where: { $0.code == selectedCountry }) {
            selectedCountry = countries[0].code
        }
        if !citiesForSelectedCountry.contains(where: { $0.code == selectedCity }) {
            selectedCity = citiesForSelectedCountry.first?.code ?? selectedCity
        }
    }

    // MARK: - Map

    public func updateMapCoordinates(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        mapRegion.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        cityValidationError = isCityValid(latitude: latitude, longitude: longitude)
            ? nil
            : "La dirección está fuera de \(selectedCityName). Elige un punto dentro de la ciudad seleccionada."

        Task { await fetchAddressFromCoordinates(latitude, longitude) }
    }

    // MARK: - Search

    public func searchAddresses(_ query: String) {
        searchQuery = query
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let results = try await geocodingService.searchAddresses(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
            isSearching = false
        }
    }

    public func selectSearchResult(_ result: GeocodingSearchResult) {
        address = result.name
        latitude = result.latitude
        longitude = result.longitude
        searchQuery = ""
        searchResults = []
        mapRegion.center = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)

        cityValidationError = isCityValid(latitude: result.latitude, longitude: result.longitude)
            ? nil
            : "La dirección está fuera de \(selectedCityName). Elige una dentro de la ciudad seleccionada."
    }

    // MARK: - Save

    public func save() async {
        isSaving = true
        errorMessage = nil

        let request = UpdateLocationRequest(
            id: locationId,
            address: address,
            countryCode: selectedCountry,
            cityCode: selectedCity,
            latitude: latitude,
            longitude: longitude
        )

        do {
            let location = try await updateLocationUseCase.execute(request: request)
            updatedLocation = location
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Private helpers

    private func isCityValid(latitude: Double, longitude: Double) -> Bool {
        guard let city = LocationCity(rawValue: selectedCity) else { return true }
        let bbox = city.boundingBox
        return latitude  >= bbox.minLat && latitude  <= bbox.maxLat
            && longitude >= bbox.minLon && longitude <= bbox.maxLon
    }

    private func fetchAddressFromCoordinates(_ latitude: Double, _ longitude: Double) async {
        do {
            address = try await geocodingService.reverseGeocode(latitude: latitude, longitude: longitude)
        } catch {
            // Silently fail — keep existing address
        }
    }
}
