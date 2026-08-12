import Foundation
import FirebaseRemoteConfig

// MARK: - Field Attribute Catalog Remote Config Repository

/// Fetches the `field_types` and `footwear_types` parameters from Firebase
/// Remote Config and caches them in UserDefaults so the catalogs are
/// available offline on later launches.
///
/// Expected Remote Config JSON (same shape for both parameters):
/// ```json
/// {
///   "options": [
///     { "code": "ARTIFICIAL_TURF", "es": "Pasto artificial", "en": "Artificial turf" }
///   ]
/// }
/// ```
///
/// Strategy (in order), applied independently per parameter:
///  1. Activate any previously fetched (but not yet active) Remote Config values.
///  2. Parse and return from the now-active Remote Config.
///  3. Fall back to the UserDefaults cache if Remote Config has no value.
///  4. Fetch fresh values from Firebase (bounded by a timeout) and persist.
///  5. Return the hardcoded enum-based fallback as last resort.
///
/// AdminFeature's UI is Spanish-only today, so the `es` field is always the
/// one used here — `en` still travels in the payload for PlayerFeature.
final class FieldAttributeCatalogRemoteConfigRepository: FieldAttributeCatalogRepositoryProtocol {

    // MARK: - Constants

    private static let fieldTypesKey = "field_types"
    private static let footwearTypesKey = "footwear_types"
    private static let fieldTypesCacheKey = "fm_field_types_cache_v1"
    private static let footwearTypesCacheKey = "fm_footwear_types_cache_v1"
    /// Minimum seconds between full Remote Config fetches (1 hour).
    private static let fetchInterval: TimeInterval = 3_600

    // MARK: - Dependencies

    /// `@autoclosure @escaping` so the default `RemoteConfig.remoteConfig()` call is
    /// captured but NOT evaluated at init time, keeping construction safe even
    /// before `FirebaseApp.configure()` runs.
    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults

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
         defaults: UserDefaults = .standard) {
        self.remoteConfigProvider = remoteConfig
        self.defaults = defaults
    }

    // MARK: - FieldAttributeCatalogRepositoryProtocol

    func fetchCatalogs() async -> FieldAttributeCatalogs {
        // 1. Activate previously fetched config (no-op if nothing pending).
        _ = try? await remoteConfig.activate()

        let fieldTypes = await fetchOptions(
            key: Self.fieldTypesKey,
            cacheKey: Self.fieldTypesCacheKey,
            fallback: FieldAttributeCatalogs.fallback.fieldTypes
        )
        let footwearTypes = await fetchOptions(
            key: Self.footwearTypesKey,
            cacheKey: Self.footwearTypesCacheKey,
            fallback: FieldAttributeCatalogs.fallback.footwearTypes
        )

        return FieldAttributeCatalogs(fieldTypes: fieldTypes, footwearTypes: footwearTypes)
    }

    // MARK: - Private helpers

    private func fetchOptions(
        key: String,
        cacheKey: String,
        fallback: [FieldAttributeOption]
    ) async -> [FieldAttributeOption] {
        // 2. Try parsing from the currently active Remote Config value.
        if let options = parsedOptions(key: key), !options.isEmpty {
            persist(options, cacheKey: cacheKey)
            return options
        }

        // 3. Try the local cache.
        if let cached = cachedOptions(cacheKey: cacheKey), !cached.isEmpty {
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
        if let options = parsedOptions(key: key), !options.isEmpty {
            return options
        }

        // 5. Hardcoded fallback.
        return fallback
    }

    private func fetchAndCache() async {
        guard (try? await remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
        _ = try? await remoteConfig.activate()
        if let fieldTypes = parsedOptions(key: Self.fieldTypesKey), !fieldTypes.isEmpty {
            persist(fieldTypes, cacheKey: Self.fieldTypesCacheKey)
        }
        if let footwearTypes = parsedOptions(key: Self.footwearTypesKey), !footwearTypes.isEmpty {
            persist(footwearTypes, cacheKey: Self.footwearTypesCacheKey)
        }
    }

    private func parsedOptions(key: String) -> [FieldAttributeOption]? {
        let raw = remoteConfig.configValue(forKey: key).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(FieldAttributeOptionsPayload.self, from: data) else { return nil }
        return payload.options.map { FieldAttributeOption(code: $0.code, nameEs: $0.es, nameEn: $0.en) }
    }

    private func persist(_ options: [FieldAttributeOption], cacheKey: String) {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    private func cachedOptions(cacheKey: String) -> [FieldAttributeOption]? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode([FieldAttributeOption].self, from: data)
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

private struct FieldAttributeOptionsPayload: Codable {
    struct Option: Codable {
        let code: String
        let es: String
        let en: String
    }

    let options: [Option]
}
