import Foundation
import FirebaseRemoteConfig
import PlayerFeature

// MARK: - HomeRankingRemoteConfigRepository

/// Keeps the `home_ranking_enabled` flag (Ranking card vs Last Match on Home) in sync with
/// Firebase and caches it in UserDefaults, where PlayerFeature reads it.
///
///  1. Activate any previously fetched config and persist it.
///  2. Listen for real-time updates, so an open Home switches cards without a relaunch.
///  3. Fetch in the background (1 min in DEBUG, 12 h in release, like Android).
///
/// The last activated value survives offline; `false` until one was ever activated.
final class HomeRankingRemoteConfigRepository {

    /// Must match the Firebase Console key exactly (shared with Android).
    private static let enabledKey = "home_ranking_enabled"

    #if DEBUG
    private static let fetchInterval: TimeInterval = 60
    #else
    private static let fetchInterval: TimeInterval = 12 * 60 * 60
    #endif

    private let remoteConfigProvider: () -> RemoteConfig
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private lazy var remoteConfig: RemoteConfig = remoteConfigProvider()
    private var updateListener: ConfigUpdateListenerRegistration?

    init(
        remoteConfig: @autoclosure @escaping () -> RemoteConfig = RemoteConfig.remoteConfig(),
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.remoteConfigProvider = remoteConfig
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    /// Call once at app launch (after `FirebaseApp.configure()`).
    func fetchAndActivate() async {
        _ = try? await remoteConfig.activate()
        await persistCurrentValue()
        await listenForRealtimeUpdates()

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            guard (try? await self.remoteConfig.fetch(withExpirationDuration: Self.fetchInterval)) != nil else { return }
            _ = try? await self.remoteConfig.activate()
            await self.persistCurrentValue()
        }
    }

    // MARK: - Private

    @MainActor
    private func listenForRealtimeUpdates() {
        guard updateListener == nil else { return }
        updateListener = remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
            guard let self, error == nil,
                  update?.updatedKeys.contains(Self.enabledKey) == true else { return }
            self.remoteConfig.activate { _, _ in
                Task { await self.persistCurrentValue() }
            }
        }
    }

    /// Writes the active value and tells Home. A key that is not in Remote Config
    /// (`source == .static`) keeps whatever was cached before.
    @MainActor
    private func persistCurrentValue() {
        let raw = remoteConfig.configValue(forKey: Self.enabledKey)
        guard raw.source != .static else { return }
        let previous = defaults.object(forKey: HomeRankingFlag.cachedEnabledKey) as? Bool
        guard previous != raw.boolValue else { return }
        defaults.set(raw.boolValue, forKey: HomeRankingFlag.cachedEnabledKey)
        notificationCenter.post(name: HomeRankingFlag.didChangeNotification, object: nil)
    }
}
