import Foundation

// MARK: - UserDefaults Match Version Store

/// Lightweight `UserDefaults`-backed store for regional cache versions.
///
/// All regions live under a single dictionary key so the whole store can be
/// wiped on logout by removing one key (see `Self.storageKey`). The match list
/// itself stays in the CoreData cache — only the `Long` version lives here.
final class UserDefaultsMatchVersionStore: MatchVersionStoreProtocol {

    /// Public so the app target can clear it on logout without re-deriving it.
    public static let storageKey = "match.regionVersions"

    /// Bump whenever the CoreData match cache gains a field that previously
    /// cached rows can't supply (e.g. venue coordinates for the distance
    /// label). Because the feed is versioned, a client holding the latest
    /// `sinceVersion` gets `hasChanges: false` and would keep serving the
    /// incomplete rows forever — so a schema bump drops the stored versions,
    /// forcing one full refetch that refills the cache with the new fields.
    /// Schema 2 → 3: changed matchStatus from String to MatchStatus enum.
    private static let cacheSchemaVersion = 3
    private static let schemaVersionKey = "match.cacheSchemaVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `integer(forKey:)` is 0 when absent, so pre-schema installs migrate too.
        if defaults.integer(forKey: Self.schemaVersionKey) < Self.cacheSchemaVersion {
            defaults.removeObject(forKey: Self.storageKey)
            defaults.set(Self.cacheSchemaVersion, forKey: Self.schemaVersionKey)
        }
    }

    func version(for region: String) -> Int64? {
        let dict = defaults.dictionary(forKey: Self.storageKey) as? [String: NSNumber]
        return dict?[region]?.int64Value
    }

    func setVersion(_ version: Int64, for region: String) {
        var dict = (defaults.dictionary(forKey: Self.storageKey) as? [String: NSNumber]) ?? [:]
        dict[region] = NSNumber(value: version)
        defaults.set(dict, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
