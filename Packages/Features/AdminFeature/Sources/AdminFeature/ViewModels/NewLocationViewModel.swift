import Foundation
import MapKit

// MARK: - New Location ViewModel

@MainActor
public final class NewLocationViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published public var selectedCountry = LocationCountry.mexico.rawValue
    @Published public var selectedCity = LocationCity.cdmx.rawValue
    @Published public private(set) var catalog: [AdminLocationCountry] = .fallback
    @Published public var address = ""
    @Published public var exteriorNumber = ""
    @Published public var latitude = NewLocationViewModel.defaultCoordinate.latitude
    @Published public var longitude = NewLocationViewModel.defaultCoordinate.longitude
    @Published public var isSaving = false
    @Published public var errorMessage: String?
    @Published public var searchQuery = ""
    @Published public var searchResults: [GeocodingSearchResult] = []
    @Published public var isSearching = false
    @Published public var mapRegion: MKCoordinateRegion
    @Published public private(set) var createdLocation: AdminLocation?
    @Published public var cityValidationError: String?

    public var isReadyToSave: Bool {
        !address.isEmpty && cityValidationError == nil
    }

    // MARK: - Private Properties

    /// CDMX — map starting point until the device location arrives.
    private static let defaultCoordinate = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)

    private let geocodingService: GeocodingServiceProtocol
    private let createLocationUseCase: CreateLocationUseCaseProtocol
    private let fetchCatalogUseCase: FetchLocationCatalogUseCaseProtocol
    private let currentLocationProvider: CurrentLocationProviding
    private var searchTask: Task<Void, Never>?
    /// Raw address returned by the geocoder. Kept separate so we can
    /// re-insert a new exterior number without duplicating it.
    private var rawGeocodedAddress = ""
    /// Once the user moves the pin or picks a search result, the device
    /// location must no longer override their choice.
    private var hasUserAdjustedPin = false

    // MARK: - Init

    init(
        geocodingService: GeocodingServiceProtocol,
        createLocationUseCase: CreateLocationUseCaseProtocol,
        fetchCatalogUseCase: FetchLocationCatalogUseCaseProtocol,
        currentLocationProvider: CurrentLocationProviding
    ) {
        self.geocodingService = geocodingService
        self.createLocationUseCase = createLocationUseCase
        self.fetchCatalogUseCase = fetchCatalogUseCase
        self.currentLocationProvider = currentLocationProvider
        self.mapRegion = MKCoordinateRegion(
            center: Self.defaultCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        super.init()
    }

    // MARK: - Lifecycle

    /// Loads the country/city catalog and centers the pin on the device's
    /// current location (requesting permission if needed).
    public func onAppear() async {
        async let catalogLoad: Void = loadCatalog()
        async let locationLoad: Void = startAtCurrentLocation()
        _ = await (catalogLoad, locationLoad)
    }

    // MARK: - Catalog

    /// Cities for the currently selected country.
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

    /// Select a city: pans the map to its center and resets the pin + address.
    public func selectCity(_ code: String) {
        selectedCity = code
        hasUserAdjustedPin = true
        cityValidationError = nil
        address = ""
        exteriorNumber = ""
        rawGeocodedAddress = ""

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
        // Re-validate the current selection against the fresh catalog.
        if !countries.contains(where: { $0.code == selectedCountry }) {
            selectedCountry = countries[0].code
        }
        if !citiesForSelectedCountry.contains(where: { $0.code == selectedCity }) {
            selectedCity = citiesForSelectedCountry.first?.code ?? selectedCity
        }
    }

    // MARK: - Current Location

    private func startAtCurrentLocation() async {
        guard let coordinate = await currentLocationProvider.requestCurrentLocation() else { return }
        // The user may have placed the pin while we waited for permission.
        guard !hasUserAdjustedPin else { return }
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        await fetchAddressFromCoordinates(coordinate.latitude, coordinate.longitude)
    }

    // MARK: - Public Methods

    /// Update coordinates when user taps or drags the pin.
    public func updateMapCoordinates(latitude: Double, longitude: Double) {
        hasUserAdjustedPin = true
        self.latitude = latitude
        self.longitude = longitude
        mapRegion.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        cityValidationError = isCityValid(latitude: latitude, longitude: longitude)
            ? nil
            : "La dirección está fuera de \(selectedCityName). Elige un punto dentro de la ciudad seleccionada."

        Task { await fetchAddressFromCoordinates(latitude, longitude) }
    }

    /// Search for addresses
    public func searchAddresses(_ query: String) {
        searchQuery = query
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce: Nominatim's usage policy allows ~1 request/second. Wait for
            // typing to settle and bail if a newer keystroke cancelled this task.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let results = try await geocodingService.searchAddresses(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isSearching = false
        }
    }

    /// Select a search result and validate it falls within the selected city.
    public func selectSearchResult(_ result: GeocodingSearchResult) {
        hasUserAdjustedPin = true
        rawGeocodedAddress = result.name
        address = addressWithExteriorNumber()
        latitude = result.latitude
        longitude = result.longitude
        searchQuery = ""
        searchResults = []
        mapRegion.center = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)

        cityValidationError = isCityValid(latitude: result.latitude, longitude: result.longitude)
            ? nil
            : "La dirección está fuera de \(selectedCityName). Elige una dentro de la ciudad seleccionada."
    }

    /// Re-inserts the current exterior number into the geocoded address.
    /// Called by the View whenever `exteriorNumber` changes.
    public func rebuildAddress() {
        guard !rawGeocodedAddress.isEmpty else { return }
        address = addressWithExteriorNumber()
    }

    /// Save location to backend
    public func save() async {
        isSaving = true
        errorMessage = nil

        let request = CreateLocationRequest(
            address: address,
            countryCode: selectedCountry,
            cityCode: selectedCity,
            latitude: latitude,
            longitude: longitude
        )

        do {
            // Success — location is created on the backend and cached locally.
            let location = try await createLocationUseCase.execute(request: request)
            createdLocation = location
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Private Methods

    private func isCityValid(latitude: Double, longitude: Double) -> Bool {
        guard let city = LocationCity(rawValue: selectedCity) else { return true }
        let bbox = city.boundingBox
        return latitude  >= bbox.minLat && latitude  <= bbox.maxLat
            && longitude >= bbox.minLon && longitude <= bbox.maxLon
    }

    private func fetchAddressFromCoordinates(_ latitude: Double, _ longitude: Double) async {
        do {
            let geocoded = try await geocodingService.reverseGeocode(
                latitude: latitude,
                longitude: longitude
            )
            rawGeocodedAddress = geocoded
            address = addressWithExteriorNumber()
        } catch {
            // Silently fail — keep existing address
        }
    }

    /// Inserts `exteriorNumber` after the street name (first segment before the
    /// first comma). If there is no comma the number is appended at the end.
    private func addressWithExteriorNumber() -> String {
        guard !exteriorNumber.isEmpty else { return rawGeocodedAddress }
        if let commaIdx = rawGeocodedAddress.firstIndex(of: ",") {
            return rawGeocodedAddress[..<commaIdx] + " " + exteriorNumber + rawGeocodedAddress[commaIdx...]
        }
        return rawGeocodedAddress.isEmpty ? exteriorNumber : rawGeocodedAddress + " " + exteriorNumber
    }
}
