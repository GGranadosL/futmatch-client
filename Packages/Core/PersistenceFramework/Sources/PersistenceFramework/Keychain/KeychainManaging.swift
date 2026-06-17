import Foundation

// MARK: - KeychainManaging

/// Abstraction over `KeychainManager` so business logic (use cases) can depend on
/// a protocol instead of the concrete singleton. This keeps dependencies injected
/// and lets tests substitute an in-memory fake without touching the real Keychain.
///
/// Only the surface consumed by injectable use cases is exposed here; code that
/// genuinely needs the full concrete API can keep using `KeychainManager` directly.
public protocol KeychainManaging {
    /// Store a value under a known `KeychainKey`.
    func save(_ value: String, for key: KeychainKey) throws

    /// Read the value for a known `KeychainKey`, or `nil` when absent.
    func retrieve(for key: KeychainKey) throws -> String?

    /// Remove the value for a known `KeychainKey`.
    func delete(for key: KeychainKey) throws

    /// Persist the tokens returned after a successful login/registration.
    func saveAuthTokens(
        accessToken: String,
        refreshToken: String,
        userId: String,
        deviceId: String,
        firebaseToken: String?
    ) throws

    /// Clear all authentication data on logout (deviceId is intentionally kept).
    func clearAuthData() throws
}

// MARK: - Conformance

/// `KeychainManager` already implements every requirement above; this just
/// declares the conformance so it can be injected as `KeychainManaging`.
extension KeychainManager: KeychainManaging {}
