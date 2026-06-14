import Foundation
import FirebaseRemoteConfig

// MARK: - Location Catalog Remote Config Repository

/// Fetches the `location_countries` parameter from Firebase Remote Config and
/// caches it in UserDefaults so the catalog is available offline on later launches.
///
/// Expected Remote Config JSON:
/// ```json
/// {
///   "countries": [
///     {
///       "iso": "MX",
///       "countryKey": "country_mexico",
///       "cities": ["MX_CDMX", "MX_GDL"]
///     }
///   ]
/// }
/// ```
///
/// Strategy (in order):
///  1. Activate any previously fetched (but not yet active) Remote Config values.
///  2. Parse and return from the now-active Remote Config.
///  3. Fall back to the UserDefaults cache if Remote Config has no value.
///  4. Fetch fresh values from Firebase (bounded by a timeout) and persist.
///  5. Return the hardcoded enum-based fallback as last resort.
final class LocationCatalogRemoteConfigRepository: LocationCatalogRepositoryProtocol {

    // MARK: - Constants

    private static let remoteConfigKey = "location_countries"
    private static let userDefaultsKey = "fm_location_countries_cache_v1"
    /// Minimum seconds between full Remote Config fetches (1 hour).
    private static let fetchInterval: TimeInterval = 3_600

    // MARK: - Dependencies

    /// `@autoclosure @escaping` so the default `RemoteConfig.remoteConfig()` call is
    /// captured but NOT evaluated at init time, keeping construction safe even
    /// before `FirebaseApp.configure()` runs.
    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults
    private let localizer: LocationLocalizer

    private lazy var remoteConfig: RemoteConfig = {
        let config = remoteConfigProvider()
        let settings = RemoteConfigSettings()
        #if DEBUG
        // During development fetch every 60 s instead of the production 1-hour minimum.
        settings.minimumFetchInterval = 60
        #else
        settings.minimumFetchInterval = Self.fetchInterval
        #endif
        config.configSettings = settings
        return config
    }()

    // MARK: - Init

    init(remoteConfig: @autoclosure @escaping () -> RemoteConfig = RemoteConfig.remoteConfig(),
         defaults: UserDefaults = .standard,
         localizer: LocationLocalizer = LocationLocalizer()) {
        self.remoteConfigProvider = remoteConfig
        self.defaults = defaults
        self.localizer = localizer
    }

    // MARK: - LocationCatalogRepositoryProtocol

    func fetchCatalog() async -> [AdminLocationCountry] {
        // 1. Activate previously fetched config (no-op if nothing pending).
        _ = try? await remoteConfig.activate()

        // 2. Try parsing from the currently active Remote Config value.
        if let countries = parsedCatalog(), !countries.isEmpty {
            persist(countries)
            return countries
        }

        // 3. Try the local cache.
        if let cached = cachedCatalog(), !cached.isEmpty {
            // Kick off a background refresh so the next call gets fresh data.
            Task.detached(priority: .background) { [weak self] in
                await self?.fetchAndCache()
            }
            return cached
        }

        // 4. Blocking fetch (first launch, no cache), bounded so a stalled
        //    Remote Config fetch can't freeze the screen.
        await withTimeout(seconds: 6) { [weak self] in
            await self?.fetchAndCache()
        }
        if let countries = parsedCatalog(), !countries.isEmpty {
            return countries
        }

        // 5. Hardcoded fallback.
        return .fallback
    }

    // MARK: - Private helpers

    private func fetchAndCache() async {
        guard (try? await remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
        _ = try? await remoteConfig.activate()
        if let countries = parsedCatalog(), !countries.isEmpty {
            persist(countries)
        }
    }

    private func parsedCatalog() -> [AdminLocationCountry]? {
        let raw = remoteConfig.configValue(forKey: Self.remoteConfigKey).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(LocationCountriesPayload.self, from: data) else { return nil }
        return payload.countries.map { country in
            AdminLocationCountry(
                code: country.iso,
                name: localizer.countryName(for: country.iso),
                cities: country.cities.map { cityCode in
                    AdminLocationCity(code: cityCode, name: localizer.cityName(for: cityCode))
                }
            )
        }
    }

    private func persist(_ countries: [AdminLocationCountry]) {
        guard let data = try? JSONEncoder().encode(countries) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    private func cachedCatalog() -> [AdminLocationCountry]? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode([AdminLocationCountry].self, from: data)
    }

    private func withTimeout(seconds: TimeInterval, operation: @escaping () async -> Void) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await operation() }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            await group.next()
            group.cancelAll()
        }
    }
}

// MARK: - Payload

private struct LocationCountriesPayload: Codable {
    struct Country: Codable {
        let iso: String
        let countryKey: String
        let cities: [String]
    }

    let countries: [Country]
}
