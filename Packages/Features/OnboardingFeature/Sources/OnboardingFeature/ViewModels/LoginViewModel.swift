import Foundation
import NetworkFramework
import PersistenceFramework

/// Login ViewModel
@MainActor
public class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorTitle = ""
    @Published var errorMessage = ""
    @Published var isLoginSuccessful = false

    // MFA State
    @Published var showMFAVerification = false
    @Published var mfaUserId = ""
    @Published var mfaDeviceId = ""
    @Published var resendCodeTimeInSeconds = 60
    @Published var verificationCode = ""

    private let loginUseCase: LoginUseCaseProtocol
    /// Called after tokens are saved. Receives the Firebase custom token.
    /// Throw to abort login (e.g. Firebase sign-in failed).
    private let firebaseSignIn: ((String) async throws -> Void)?

    public init(
        loginUseCase: LoginUseCaseProtocol? = nil,
        firebaseSignIn: ((String) async throws -> Void)? = nil
    ) {
        self.loginUseCase = loginUseCase ?? LoginUseCase(authService: AuthService())
        self.firebaseSignIn = firebaseSignIn
    }
    
    var isFormValid: Bool {
        FieldValidator.validateEmail(email).isValid &&
        FieldValidator.validatePassword(password).isValid
    }
    
    func login() async {
        isLoading = true
        isLoginSuccessful = false
        showError = false

        do {
            let result = try await loginUseCase.execute(email: email, password: password)

            if result.requiresMFA {
                isLoading = false
                mfaUserId = result.userId
                mfaDeviceId = result.deviceId
                resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
                showMFAVerification = true
            } else {
                try await performFirebaseSignIn()
                isLoading = false
                isLoginSuccessful = true
            }
        } catch {
            isLoading = false
            handleError(error)
        }
    }

    func verifyMFACode() async {
        isLoading = true
        showError = false

        do {
            _ = try await loginUseCase.verifyMFACode(
                userId: mfaUserId,
                deviceId: mfaDeviceId,
                code: verificationCode
            )
            try await performFirebaseSignIn()
            isLoading = false
            showMFAVerification = false
            isLoginSuccessful = true
        } catch {
            isLoading = false
            handleError(error)
        }
    }
    
    func resendMFACode() async {
        isLoading = true
        showError = false
        
        do {
            let result = try await loginUseCase.sendMFACode(
                userId: mfaUserId,
                deviceId: mfaDeviceId
            )
            isLoading = false
            resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
        } catch {
            isLoading = false
            handleError(error)
        }
    }
    
    // MARK: - Private Helpers

    /// Reads the Firebase token saved by the use case and calls the injected sign-in closure.
    /// Throws `AuthError.firebaseSignInFailed` if the token is missing or sign-in fails.
    private func performFirebaseSignIn() async throws {
        guard let signIn = firebaseSignIn else { return }
        guard let token = KeychainManager.shared.firebaseToken, !token.isEmpty else {
            throw AuthError.firebaseSignInFailed
        }
        try await signIn(token)
    }

    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            errorTitle = apiError.errorTitle
        } else {
            errorTitle = L10n.Login.errorTitle
        }
        errorMessage = error.localizedDescription
        showError = true
    }
}
