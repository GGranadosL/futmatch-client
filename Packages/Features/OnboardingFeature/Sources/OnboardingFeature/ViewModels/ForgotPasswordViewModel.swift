import Foundation

/// Forgot Password ViewModel
@MainActor
public class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var resendCodeTime: Int = 0
    
    private let forgotPasswordUseCase: ForgotPasswordUseCaseProtocol
    
    public init(forgotPasswordUseCase: ForgotPasswordUseCaseProtocol? = nil) {
        self.forgotPasswordUseCase = forgotPasswordUseCase ?? ForgotPasswordUseCase(authService: AuthService())
    }
    
    var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    func sendResetEmail() async {
        isLoading = true
        showError = false
        
        do {
            let result = try await forgotPasswordUseCase.execute(email: email)
            isLoading = false
            resendCodeTime = result.data.resendCodeTimeInSeconds
            showSuccess = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
