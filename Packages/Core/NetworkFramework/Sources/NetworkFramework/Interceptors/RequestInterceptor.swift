import Foundation
import UIKit

public protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

public struct AuthTokenInterceptor: RequestInterceptor {
    private let tokenProvider: () async throws -> String?
    
    public init(tokenProvider: @escaping () async throws -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    public func intercept(_ request: inout URLRequest) async throws {
        guard request.value(forHTTPHeaderField: "Authorization") == nil else { return }
        if let token = try await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Logging Interceptor
public struct LoggingInterceptor: RequestInterceptor {
    public init() {}
    
    public func intercept(_ request: inout URLRequest) async throws {
        print("📡 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
    }
}

// MARK: - Refresh Token Interceptor
public struct RefreshTokenInterceptor: RequestInterceptor {
    private let tokenProvider: () async throws -> String
    private let tokenExpirationChecker: () -> Bool
    
    public init(
        tokenProvider: @escaping () async throws -> String,
        tokenExpirationChecker: @escaping () -> Bool
    ) {
        self.tokenProvider = tokenProvider
        self.tokenExpirationChecker = tokenExpirationChecker
    }
    
    public func intercept(_ request: inout URLRequest) async throws {
        // Si el token expiró, renovarlo automáticamente
        if tokenExpirationChecker() {
            let newToken = try await tokenProvider()
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - User-Agent Interceptor
public struct UserAgentInterceptor: RequestInterceptor {
    private let userAgent: String
    
    public init() {
        #if os(iOS)
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        self.userAgent = "FutMatch/\(appVersion) (iOS \(systemVersion); \(deviceModel); Build \(appBuild))"
        #else
        self.userAgent = "FutMatch/1.0.0"
        #endif
    }
    
    public func intercept(_ request: inout URLRequest) async throws {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
}
