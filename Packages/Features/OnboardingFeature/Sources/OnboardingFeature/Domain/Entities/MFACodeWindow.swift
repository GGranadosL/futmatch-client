import Foundation

/// The two countdowns the backend reports alongside every emailed code, stored as
/// absolute dates.
///
/// Every MFA flow in the app previously kept a decrementing `Int` in view state, so
/// the countdown drifted the moment the app was backgrounded and nothing at all
/// stopped a code from being submitted long after it had expired. Absolute dates
/// survive backgrounding and relaunch: the view recomputes the remaining seconds
/// from `Date()` instead of trusting a counter it may not have been alive to tick.
///
/// Both values come from the response — never from a constant. The defaults on
/// `init` exist only for the endpoints that don't report a duration yet.
public struct MFACodeWindow: Equatable {
    /// When the emailed code stops being accepted.
    public let codeExpiresAt: Date
    /// When the user may request a new code.
    public let resendAvailableAt: Date

    public init(codeExpiresAt: Date, resendAvailableAt: Date) {
        self.codeExpiresAt = codeExpiresAt
        self.resendAvailableAt = resendAvailableAt
    }

    /// - Parameters:
    ///   - expiresInSeconds: `expiresInSeconds` from the backend. Pass the flow's
    ///     documented default when the endpoint doesn't report one yet.
    ///   - resendCodeTimeInSeconds: `resendCodeTimeInSeconds` from the backend.
    ///   - now: injectable clock, for tests.
    public init(expiresInSeconds: Int, resendCodeTimeInSeconds: Int, now: Date = Date()) {
        self.codeExpiresAt = now.addingTimeInterval(TimeInterval(max(0, expiresInSeconds)))
        self.resendAvailableAt = now.addingTimeInterval(TimeInterval(max(0, resendCodeTimeInSeconds)))
    }

    public func isCodeExpired(at now: Date = Date()) -> Bool {
        now >= codeExpiresAt
    }

    /// An expired code always unlocks the resend button, whatever the cooldown says —
    /// otherwise the user is left on a dead screen with nothing to press.
    public func canResend(at now: Date = Date()) -> Bool {
        now >= resendAvailableAt || isCodeExpired(at: now)
    }

    public func secondsUntilResend(at now: Date = Date()) -> Int {
        max(0, Int(resendAvailableAt.timeIntervalSince(now).rounded(.up)))
    }

    public func secondsUntilExpiry(at now: Date = Date()) -> Int {
        max(0, Int(codeExpiresAt.timeIntervalSince(now).rounded(.up)))
    }
}

/// Code lifetimes to assume when an endpoint doesn't report `expiresInSeconds` yet.
///
/// These mirror the values the backend documents today. They are a floor, not a
/// policy: whenever the response carries a duration, that value wins.
public enum MFADefaults {
    /// Registration email code — 1 hour.
    public static let registration = 3600
    /// Login MFA, password recovery and social linking — 5 minutes.
    public static let shortLived = 300
    /// The token handed out after a successful recovery code — 10 minutes.
    public static let resetToken = 600
    /// A linking attempt (`linkAttemptToken`) — 10 minutes, single use.
    public static let linkAttempt = 600
    /// Resend cooldown used when a response omits it.
    public static let resendCooldown = 60
}
