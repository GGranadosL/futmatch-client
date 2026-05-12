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
    public let resendCodeTimeInSeconds: Int
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
            resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
        )
    }
}
