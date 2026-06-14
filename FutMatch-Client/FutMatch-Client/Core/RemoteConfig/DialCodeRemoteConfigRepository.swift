import Foundation
import FirebaseRemoteConfig
import SharedModels

// MARK: - Dial Code Remote Config Repository

/// Fetches the `phone_dial_codes` parameter from Firebase Remote Config and caches it
/// in UserDefaults so the list is available offline on subsequent launches.
///
/// Strategy (in order):
///  1. Activate any previously fetched (but not yet active) Remote Config values.
///  2. Parse and return from the now-active Remote Config.
///  3. Fall back to the UserDefaults cache if Remote Config has no value.
///  4. Fetch fresh values from Firebase (blocking on first launch) and persist to cache.
///  5. Return the hardcoded `DialCode.fallback` list as last resort.
final class DialCodeRemoteConfigRepository: DialCodeRepositoryProtocol {

    // MARK: - Constants

    private static let remoteConfigKey = "phone_dial_codes"
    private static let userDefaultsKey = "fm_dial_code_list_cache_v1"
    /// Minimum seconds between full Remote Config fetches (1 hour).
    private static let fetchInterval: TimeInterval = 3_600

    // MARK: - Dependencies

    /// `@autoclosure @escaping` so the default `RemoteConfig.remoteConfig()` call is
    /// captured but NOT evaluated at init time. This lets the repository be created
    /// as a stored property of `@main App` (i.e. before `FirebaseApp.configure()` runs).
    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults

    /// Lazily resolved on first access. By the time any view code triggers a fetch,
    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)` has already
    /// configured Firebase, so `RemoteConfig.remoteConfig()` is safe to call.
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

    // MARK: - DialCodeRepositoryProtocol

    func fetchDialCodes() async -> [DialCode] {
        // 1. Activate previously fetched config (no-op if nothing pending).
        _ = try? await remoteConfig.activate()

        // 2. Try parsing from the currently active Remote Config value.
        if let dialCodes = parsedDialCodes(), !dialCodes.isEmpty {
            persist(dialCodes)
            return dialCodes
        }

        // 3. Try the local cache.
        if let cached = cachedDialCodes(), !cached.isEmpty {
            // Kick off a background refresh so the next call gets fresh data.
            Task.detached(priority: .background) { [weak self] in
                await self?.fetchAndCache()
            }
            return cached
        }

        // 4. Blocking fetch (first launch, no cache). Bounded with a timeout so a
        //    stalled App-Check-gated Remote Config fetch can't freeze the launch
        //    splash — we fall through to the hardcoded list instead.
        _ = await withTimeout(seconds: 6) { [weak self] in
            await self?.fetchAndCache()
        }
        if let dialCodes = parsedDialCodes(), !dialCodes.isEmpty {
            return dialCodes
        }

        // 5. Hardcoded fallback — should never be reached after first successful fetch.
        return DialCode.fallback
    }

    // MARK: - Private helpers

    private func fetchAndCache() async {
        guard (try? await remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
        _ = try? await remoteConfig.activate()
        if let dialCodes = parsedDialCodes(), !dialCodes.isEmpty {
            persist(dialCodes)
        }
    }

    private func parsedDialCodes() -> [DialCode]? {
        let raw = remoteConfig.configValue(forKey: Self.remoteConfigKey).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return (try? JSONDecoder().decode(DialCodeListPayload.self, from: data))?.dialCodes
    }

    private func persist(_ dialCodes: [DialCode]) {
        guard let data = try? JSONEncoder().encode(dialCodes) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    private func cachedDialCodes() -> [DialCode]? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode([DialCode].self, from: data)
    }
}
