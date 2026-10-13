import Foundation

// MARK: - Protocol
public protocol StartSocialLinkUseCaseProtocol {
    /// Validates the account's password and asks the backend to email a code.
    /// - Returns: the code/resend windows the backend reports, so the UI counts
    ///   down from its values rather than from a constant.
    func execute(linkAttemptToken: String, password: String) async throws -> MFACodeWindow
}

// MARK: - Implementation

/// Second of the three proofs required to add a social identity to an existing
/// account: the account's current Futmatch password.
///
/// Calling this again with the same `linkAttemptToken` is how a resend works — the
/// attempt token stays valid for its full 10 minutes, and each call restarts the
/// code's own 5-minute window.
public struct StartSocialLinkUseCase: StartSocialLinkUseCaseProtocol {
    private let authService: AuthServiceProtocol

    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    public func execute(linkAttemptToken: String, password: String) async throws -> MFACodeWindow {
        let response = try await authService.startSocialLink(
            linkAttemptToken: linkAttemptToken,
            password: password
        )
        return MFACodeWindow(
            expiresInSeconds: response.data.expiresInSeconds,
            resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
        )
    }
}
