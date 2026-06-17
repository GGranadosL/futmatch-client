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

// MARK: - App Check Interceptor
/// Attaches a Firebase App Check token to outgoing requests so the backend can
/// verify they originate from a genuine, untampered instance of the app.
///
/// The token is supplied via an injected closure to keep NetworkFramework free
/// of any Firebase dependency. The provider is built at the app level where
/// `FirebaseAppCheck` is available. A nil/throwing provider results in the
/// request being sent without the header (backend decides enforcement).
public struct AppCheckInterceptor: RequestInterceptor {
    private let tokenProvider: () async throws -> String?
    private let timeout: Duration

    /// - Parameters:
    ///   - timeout: Maximum time to wait for a token before sending the request
    ///     without the header. App Check token fetches can stall on retry backoff
    ///     (e.g. an unregistered debug token); a bounded wait keeps that from
    ///     freezing app startup. Defaults to 3 seconds.
    public init(
        timeout: Duration = .seconds(3),
        tokenProvider: @escaping () async throws -> String?
    ) {
        self.tokenProvider = tokenProvider
        self.timeout = timeout
    }

    public func intercept(_ request: inout URLRequest) async throws {
        guard request.value(forHTTPHeaderField: "X-Firebase-AppCheck") == nil else { return }
        if let token = await tokenWithinTimeout() {
            request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
    }

    /// Races the token fetch against a timeout. Returns nil on timeout or error
    /// so a slow/failing App Check never blocks the request.
    private func tokenWithinTimeout() async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { try? await tokenProvider() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
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
