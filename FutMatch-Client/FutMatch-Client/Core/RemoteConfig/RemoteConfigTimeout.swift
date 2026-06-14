import Foundation

/// Runs an async operation but gives up after `seconds`, returning `nil` on timeout.
///
/// Used to bound blocking Remote Config fetches at launch. Remote Config is gated by
/// Firebase App Check; if an attestation token can't be obtained (e.g. an unregistered
/// debug token), the underlying fetch can stall for minutes on retry backoff. A bounded
/// wait lets the app fall back to cached/hardcoded data instead of freezing on the splash.
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
