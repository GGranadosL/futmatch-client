import Foundation
import NetworkFramework
import PersistenceFramework

/// A `LINK_REQUIRED` answer, ready to drive presentation.
///
/// `Identifiable` off the account so `sheet(item:)` / `fullScreenCover(item:)` can
/// key on it, the same way `LoginViewModel.socialSignUpAccount` already does.
public struct SocialLinkRequest: Identifiable, Equatable {
    public let account: SocialAccount
    public let linkAttemptToken: String

    public init(account: SocialAccount, linkAttemptToken: String) {
        self.account = account
        self.linkAttemptToken = linkAttemptToken
    }

    public var id: String { account.id }
}

/// Drives adding Google or Apple to an account that already signs in with email and
/// password: confirm, type the account password, then the code emailed to it.
///
/// Deliberately separate from `LoginViewModel`, which already carries the email
/// form, the social buttons, the login MFA challenge and the social sign-up cover.
///
/// **Nothing here is persisted.** The attempt token, the password and the provider
/// credential live only on this object and are wiped by `cancel()`, on success, and
/// when the attempt expires. In particular this flow never touches
/// `SaveOnboardingDraftUseCase` — the social *sign-up* path does, and that draft
/// goes to CoreData.
@MainActor
public final class SocialLinkViewModel: ObservableObject {

    public enum Stage: Equatable {
        /// Explicit confirmation plus the account's password.
        case password
        /// The code emailed to the existing account.
        case mfa
    }

    @Published public private(set) var stage: Stage = .password
    @Published public var password = ""
    @Published public var code = ""
    @Published public private(set) var isLoading = false
    /// Countdowns as reported by `/auth/social-link/start` — never constants.
    @Published public private(set) var codeWindow: MFACodeWindow?
    @Published public var errorMessage: String?
    @Published public private(set) var succeeded = false
    /// The attempt or the provider credential died. The flow cannot be resumed;
    /// the user has to tap the provider button again, which re-runs `resolve`.
    @Published public private(set) var isExpired = false

    private let account: SocialAccount
    private var linkAttemptToken: String?
    /// The backend gives an attempt token 10 minutes and one use. Tracked locally so
    /// a dead attempt is reported immediately instead of by a failed round trip.
    private let attemptExpiresAt: Date

    private let startSocialLinkUseCase: StartSocialLinkUseCaseProtocol
    private let confirmSocialLinkUseCase: ConfirmSocialLinkUseCaseProtocol
    /// Same injected closure `LoginViewModel` uses: receives the Firebase custom token.
    private let firebaseSignIn: ((String) async throws -> Void)?
    private let keychainManager: KeychainManaging

    public init(
        account: SocialAccount,
        linkAttemptToken: String,
        startSocialLinkUseCase: StartSocialLinkUseCaseProtocol,
        confirmSocialLinkUseCase: ConfirmSocialLinkUseCaseProtocol,
        firebaseSignIn: ((String) async throws -> Void)? = nil,
        keychainManager: KeychainManaging = KeychainManager.shared,
        now: Date = Date()
    ) {
        self.account = account
        self.linkAttemptToken = linkAttemptToken
        self.attemptExpiresAt = now.addingTimeInterval(TimeInterval(MFADefaults.linkAttempt))
        self.startSocialLinkUseCase = startSocialLinkUseCase
        self.confirmSocialLinkUseCase = confirmSocialLinkUseCase
        self.firebaseSignIn = firebaseSignIn
        self.keychainManager = keychainManager
    }

    /// Named in the confirmation copy. Nothing else about the existing account is
    /// shown — not the email — because at this point ownership is unproven.
    public var providerName: String { account.provider.displayName }

    public var isPasswordValid: Bool { !password.isEmpty }
    public var isCodeComplete: Bool { code.count == 6 }

    // MARK: - Steps

    /// Validates the password and triggers the emailed code.
    public func startLink() async {
        guard !isLoading else { return }
        guard let token = validAttemptToken() else { return }

        isLoading = true
        errorMessage = nil

        do {
            codeWindow = try await startSocialLinkUseCase.execute(
                linkAttemptToken: token,
                password: password
            )
            isLoading = false
            stage = .mfa
        } catch {
            isLoading = false
            errorMessage = message(forStartFailure: error)
        }
    }

    /// Re-runs `/auth/social-link/start` — which is what a resend is for this flow.
    /// Requires the password to still be in memory; see the type's note.
    public func resendCode() async {
        guard !isLoading else { return }
        guard let token = validAttemptToken() else { return }

        isLoading = true
        errorMessage = nil
        code = ""

        do {
            codeWindow = try await startSocialLinkUseCase.execute(
                linkAttemptToken: token,
                password: password
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    /// Final step. Never retried automatically — the attempt token is single-use, so
    /// a silent retry would burn it.
    public func confirm() async {
        guard !isLoading else { return }
        guard let token = validAttemptToken() else { return }
        guard let window = codeWindow, !window.isCodeExpired() else {
            errorMessage = L10n.MFA.codeExpired
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await confirmSocialLinkUseCase.execute(
                linkAttemptToken: token,
                code: code,
                account: account
            )
            try await performFirebaseSignIn()
            clearSensitiveState()
            isLoading = false
            succeeded = true
        } catch SocialAuthError.reauthenticationRequired {
            isLoading = false
            expire()
        } catch {
            isLoading = false
            code = ""
            errorMessage = error.localizedDescription
        }
    }

    /// The user backed out. Everything sensitive goes now, not whenever the object
    /// happens to be released.
    public func cancel() {
        clearSensitiveState()
    }

    // MARK: - Private

    /// One message for every rejection the server issues. It does not say whether the
    /// password was wrong, the attempt token stale or the account nonexistent, and
    /// guessing would turn this screen into an oracle for "is this address
    /// registered?" — answerable by anyone holding a provider token.
    ///
    /// A failure that never reached the server is different: it reveals nothing, and
    /// telling someone to check their password when their connection dropped just
    /// sends them looking for the wrong problem.
    private func message(forStartFailure error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        switch apiError {
        case .serverError, .unauthorized, .notFound:
            return L10n.Login.linkInvalidCredentials
        case .invalidURL, .invalidResponse, .decodingError, .networkError, .unknown:
            return apiError.localizedDescription
        }
    }

    /// Returns the attempt token, or trips the expired state and returns `nil`.
    private func validAttemptToken() -> String? {
        guard let token = linkAttemptToken, Date() < attemptExpiresAt else {
            expire()
            return nil
        }
        return token
    }

    private func expire() {
        clearSensitiveState()
        errorMessage = L10n.Login.linkExpired
        isExpired = true
    }

    private func clearSensitiveState() {
        password = ""
        code = ""
        linkAttemptToken = nil
    }

    /// Mirrors `LoginViewModel.performFirebaseSignIn` — the tokens were just written
    /// by the use case, so the Firebase custom token is read back from the Keychain.
    private func performFirebaseSignIn() async throws {
        guard let signIn = firebaseSignIn else { return }
        guard let token = try? keychainManager.retrieve(for: .firebaseToken), !token.isEmpty else {
            throw AuthError.firebaseSignInFailed
        }
        try await signIn(token)
    }
}
