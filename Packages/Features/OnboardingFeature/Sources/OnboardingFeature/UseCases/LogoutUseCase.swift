import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol LogoutUseCaseProtocol {
    func execute() async throws
}

// MARK: - Implementation
public final class LogoutUseCase: LogoutUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.keychainManager = keychainManager
    }
    
    public func execute() async throws {
        // Call API to sign out
        _ = try await authService.signOut()
        
        // Clear local auth data
        try keychainManager.clearAuthData()
    }
}
