import Foundation

// MARK: - API Environment Configuration

/// Centralized API environment configuration.
/// Set `baseURL` once at app launch — all endpoints inherit it automatically.
///
/// ```swift
/// // In your App init:
/// APIEnvironment.baseURL = "https://futmatch-hey1.onrender.com"
/// ```
public enum APIEnvironment {
    
    /// Base URL for all API endpoints. Must be set before making any requests.
    public static var baseURL: String = "" {
        didSet {
            #if DEBUG
            print("🌐 APIEnvironment.baseURL set to: \(baseURL)")
            #endif
        }
    }
}
