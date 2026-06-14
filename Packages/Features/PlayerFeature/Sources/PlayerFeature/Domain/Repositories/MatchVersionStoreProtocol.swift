import Foundation

// MARK: - Match Version Store Protocol

/// Persists the last-seen regional cache version for the versioned matches feed
/// (`GET /match/matches/v2`). The version is sent back as `sinceVersion` so the
/// backend can answer `hasChanges=false` without re-sending the full list.
protocol MatchVersionStoreProtocol {
    /// Returns the locally stored version for `region` (the `MatchRegion.key`),
    /// or `nil` if none has been persisted yet.
    func version(for region: String) -> Int64?
    /// Stores the latest version returned by the backend for `region`.
    func setVersion(_ version: Int64, for region: String)
    /// Removes all stored versions (called on logout).
    func clear()
}
