import Foundation

/// Abstraction for the local persistence of pending payment data after a join.
/// The backend is the source of truth; this store is a short-lived recovery cache
/// only when the app is relaunch/reinstalled/Keychain-cleared.
protocol PendingPaymentStoreProtocol {
    /// Loads cached payment data for a match. Returns nil if not found or corrupted.
    func load(matchId: String) -> JoinMatchData?

    /// Persists payment data locally. Called after a successful join.
    func save(_ data: JoinMatchData, matchId: String) -> Void

    /// Clears persisted payment data for a match. Called after payment
    /// completes, or when the reservation expires/is cancelled.
    func clear(matchId: String) -> Void
}
