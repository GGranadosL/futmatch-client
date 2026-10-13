import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol RegisterUserUseCaseProtocol {
    func execute(request: RegisterStartRequest) async throws -> RegisterStartResult
}

// MARK: - Result
public struct RegisterStartResult {
    public let success: Bool
    public let message: String
    /// Code and resend countdowns as reported by the backend. The registration
    /// endpoints do not send `expiresInSeconds` yet, so that half falls back to the
    /// documented one-hour lifetime until they do.
    public let codeWindow: MFACodeWindow
}

// MARK: - Implementation
public final class RegisterUserUseCase: RegisterUserUseCaseProtocol {
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public func execute(request: RegisterStartRequest) async throws -> RegisterStartResult {
        let response = try await authService.registerStart(request)
        
        return RegisterStartResult(
            success: response.data.success,
            message: response.data.message,
            codeWindow: MFACodeWindow(
                expiresInSeconds: response.data.expiresInSeconds ?? MFADefaults.registration,
                resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
            )
        )
    }
}
