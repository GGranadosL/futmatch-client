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

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
