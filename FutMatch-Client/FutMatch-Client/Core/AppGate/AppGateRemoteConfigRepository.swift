import Foundation
import FirebaseRemoteConfig

final class AppGateRemoteConfigRepository {

    private static let maintenanceKey = "app_maintenance_config"
    private static let updateKey = "app_update_config"

    private static let cachedMaintenanceKey = "appgate.maintenance_config"
    private static let cachedUpdateKey = "appgate.update_config"

    private static let fetchInterval: TimeInterval = 3_600

    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults

    private lazy var remoteConfig: RemoteConfig = {
        let config = remoteConfigProvider()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = Self.fetchInterval
        #endif
        config.configSettings = settings
        return config
    }()

    init(
        remoteConfig: @autoclosure @escaping () -> RemoteConfig = RemoteConfig.remoteConfig(),
        defaults: UserDefaults = .standard
    ) {
        self.remoteConfigProvider = remoteConfig
        self.defaults = defaults
    }

    // MARK: - Synchronous cache reads

    var maintenanceConfig: AppMaintenanceConfig {
        guard
            let data = defaults.data(forKey: Self.cachedMaintenanceKey),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let config = AppMaintenanceConfig(json: json)
        else { return .safe }
        return config
    }

    var updateConfig: AppUpdateConfig {
        guard
            let data = defaults.data(forKey: Self.cachedUpdateKey),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let config = AppUpdateConfig(json: json)
        else { return .safe }
        return config
    }

    // MARK: - Fetch & Activate

    /// Fetches fresh values from Firebase, activates them, and persists to cache.
    /// Awaits the network call so the caller can read accurate values immediately after.
    /// Falls back to previously cached values if the network request fails.
    func fetchAndActivate() async {
        _ = try? await remoteConfig.fetchAndActivate()
        persistCurrentValues()
    }

    // MARK: - Private

    private func persistCurrentValues() {
        persist(key: Self.maintenanceKey, into: Self.cachedMaintenanceKey)
        persist(key: Self.updateKey, into: Self.cachedUpdateKey)
    }

    private func persist(key: String, into cacheKey: String) {
        let value = remoteConfig.configValue(forKey: key)
        guard value.source != .static else {
            defaults.removeObject(forKey: cacheKey)
            return
        }
        let data = value.dataValue
        guard !data.isEmpty,
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else { return }
        defaults.set(data, forKey: cacheKey)
    }
}
