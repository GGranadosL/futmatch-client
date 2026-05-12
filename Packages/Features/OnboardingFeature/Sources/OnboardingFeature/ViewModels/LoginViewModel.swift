import Foundation
import NetworkFramework

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
    
    public init(loginUseCase: LoginUseCaseProtocol? = nil) {
        self.loginUseCase = loginUseCase ?? LoginUseCase(authService: AuthService())
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
            isLoading = false
            
            if result.requiresMFA {
                // Navigate to MFA verification
                mfaUserId = result.userId
                mfaDeviceId = result.deviceId
                resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
                showMFAVerification = true
            } else {
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
