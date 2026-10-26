import Foundation
import NetworkFramework

/// A single analytics value. Booleans are deliberately absent: the shared
/// contract normalises them to `1` / `0` so both platforms send the same type.
public enum AnalyticsValue: Equatable {
    case string(String)
    case int(Int)
    case double(Double)

    public static func flag(_ value: Bool) -> AnalyticsValue { .int(value ? 1 : 0) }
}

public struct AnalyticsEvent: Equatable {
    public let name: String
    public let parameters: [String: AnalyticsValue]

    public init(name: String, parameters: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

public protocol AnalyticsTracking {
    func log(_ event: AnalyticsEvent)
}

public struct NoOpAnalytics: AnalyticsTracking {
    public init() {}
    public func log(_ event: AnalyticsEvent) {}
}

/// Process-wide hand-off between the app target (which owns the Firebase-backed
/// tracker) and the feature `DependencyFactory`s. Only factories read `current`;
/// view models receive an `AnalyticsTracking` through their initialiser.
public enum AnalyticsRegistry {
    private static var tracker: AnalyticsTracking = NoOpAnalytics()

    public static func configure(_ tracking: AnalyticsTracking) { tracker = tracking }

    /// A forwarder, not the tracker itself: it resolves the registered tracker on
    /// every `log`, so a view model created before `configure(_:)` still reports.
    public static var current: AnalyticsTracking { ForwardingAnalytics() }

    private struct ForwardingAnalytics: AnalyticsTracking {
        func log(_ event: AnalyticsEvent) { AnalyticsRegistry.tracker.log(event) }
    }
}

// MARK: - Error codes

public enum AnalyticsErrorCode {
    public static let unknown = "UNKNOWN"

    /// Stable, message-free code for an error: the backend code when present,
    /// then the HTTP status, then a coarse local category.
    public static func from(_ error: Error) -> String {
        if let code = error.apiErrorCode { return code }
        if let status = error.apiStatusCode { return "http_\(status)" }
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError: return "network"
            case .decodingError: return "decoding"
            case .invalidResponse, .invalidURL: return "invalid_response"
            default: return unknown
            }
        }
        if error is URLError { return "network" }
        return unknown
    }
}

// MARK: - Shared enums (literals are part of the cross-platform contract)

public enum AnalyticsAuthMethod: String {
    case email
    case google
    case apple
}

public enum AnalyticsJoinSource: String {
    case nearby
    case booked
}

public enum AnalyticsTeam: String {
    case a, b, none

    /// Maps the API-facing team string (`"A"`, `"B"`, `nil`) to the contract value.
    public init(apiTeam: String?) {
        switch apiTeam?.lowercased() {
        case "a": self = .a
        case "b": self = .b
        default: self = .none
        }
    }
}
