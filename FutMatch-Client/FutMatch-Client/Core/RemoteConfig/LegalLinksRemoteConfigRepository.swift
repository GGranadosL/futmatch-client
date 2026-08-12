import Foundation
import FirebaseRemoteConfig
import SharedModels

// MARK: - LegalLinksRemoteConfigRepository

/// Fetches the `settings_legal_urls` JSON parameter (help/terms/privacy URLs
/// shown in Settings and during onboarding) from Firebase Remote Config and
/// caches it in UserDefaults so it's available synchronously on subsequent
/// launches.
///
/// Fetch strategy (same as `AdminRemoteConfigRepository`):
///  1. Activate any previously-fetched (but not yet active) config.
///  2. Parse and persist the now-active value.
///  3. Trigger a background refresh for the next launch.
final class LegalLinksRemoteConfigRepository: LegalLinksProtocol {

    // MARK: - Keys (must match Firebase Console exactly)

    private static let remoteConfigKey = "settings_legal_urls"
    private static let fetchInterval: TimeInterval = 3_600   // 1 hour in production

    // MARK: - Dependencies

    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults

    private lazy var remoteConfig: RemoteConfig = {
        let config = remoteConfigProvider()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 60
        #else
        settings.minimumFetchInterval = Self.fetchInterval
        #endif
        config.configSettings = settings
        return config
    }()

    // MARK: - Init

    init(
        remoteConfig: @autoclosure @escaping () -> RemoteConfig = RemoteConfig.remoteConfig(),
        defaults: UserDefaults = .standard
    ) {
        self.remoteConfigProvider = remoteConfig
        self.defaults = defaults
    }

    // MARK: - LegalLinksProtocol (synchronous — reads UserDefaults cache)

    var helpURL: URL { LegalLinksConfig(defaults: defaults).helpURL }
    var termsURL: URL { LegalLinksConfig(defaults: defaults).termsURL }
    var privacyURL: URL { LegalLinksConfig(defaults: defaults).privacyURL }

    // MARK: - Fetch & Activate

    /// Call once at app launch (after `FirebaseApp.configure()`).
    /// Activates any pending config and kicks off a background refresh.
    func fetchAndActivate() async {
        _ = try? await remoteConfig.activate()
        await persistCurrentValueOnMainThread()

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            guard (try? await self.remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
            _ = try? await self.remoteConfig.activate()
            await self.persistCurrentValueOnMainThread()
        }
    }

    // MARK: - Private

    /// Persiste en el main thread para evitar race conditions con UserDefaults.
    @MainActor
    private func persistCurrentValueOnMainThread() {
        persistCurrentValue()
    }

    private func persistCurrentValue() {
        let raw = remoteConfig.configValue(forKey: Self.remoteConfigKey).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return }
        // Validate it decodes before caching, so a malformed remote value can't
        // clobber a previously-good cache.
        guard (try? JSONDecoder().decode(LegalLinksPayload.self, from: data)) != nil else { return }
        defaults.set(data, forKey: LegalLinksConfig.cacheKey)
    }
}
