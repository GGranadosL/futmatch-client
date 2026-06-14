import Foundation
import FirebaseRemoteConfig
import AdminFeature

// MARK: - AdminRemoteConfigRepository

/// Fetches admin-feature Remote Config values from Firebase and caches them
/// in UserDefaults so they're available synchronously on subsequent launches.
///
/// Fetch strategy (same as `CountryRemoteConfigRepository`):
///  1. Activate any previously-fetched (but not yet active) config.
///  2. Parse and persist the now-active values.
///  3. Trigger a background refresh for the next launch.
final class AdminRemoteConfigRepository: AdminRemoteConfigProtocol {

    // MARK: - Keys (must match Firebase Console exactly)

    private static let maxImagesKey      = "admin_field_max_images"
    private static let featureEnabledKey = "admin_feature_enabled"

    // UserDefaults keys (namespaced to avoid collisions)
    private static let cachedMaxImagesKey      = AdminRemoteConfig.maxImagesKey
    private static let cachedFeatureEnabledKey = AdminRemoteConfig.featureEnabledKey

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

    // MARK: - AdminRemoteConfigProtocol (synchronous — reads UserDefaults cache)

    var maxFieldImages: Int {
        let stored = defaults.integer(forKey: Self.cachedMaxImagesKey)
        return stored > 0 ? stored : 1
    }

    var isAdminFeatureEnabled: Bool {
        (defaults.object(forKey: Self.cachedFeatureEnabledKey) as? Bool) ?? true
    }

    // MARK: - Fetch & Activate

    /// Call once at app launch (after `FirebaseApp.configure()`).
    /// Activates any pending config and kicks off a background refresh.
    func fetchAndActivate() async {
        _ = try? await remoteConfig.activate()
        persistCurrentValues()

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            guard (try? await self.remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
            _ = try? await self.remoteConfig.activate()
            self.persistCurrentValues()
        }
    }

    // MARK: - Private

    private func persistCurrentValues() {
        let maxImages = remoteConfig
            .configValue(forKey: Self.maxImagesKey)
            .numberValue.intValue
        if maxImages > 0 {
            defaults.set(maxImages, forKey: Self.cachedMaxImagesKey)
        }

        // Only persist if the key actually exists in Remote Config
        let raw = remoteConfig.configValue(forKey: Self.featureEnabledKey)
        if raw.source != .static {
            defaults.set(raw.boolValue, forKey: Self.cachedFeatureEnabledKey)
        }
    }
}
