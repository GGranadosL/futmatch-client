import FirebaseAnalytics
import SharedModels

/// Firebase-backed implementation of the shared analytics contract. Lives in the
/// app target so feature packages never link the Analytics SDK.
struct FirebaseAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {
        let parameters: [String: Any] = event.parameters.mapValues { value in
            switch value {
            case .string(let string): return string
            case .int(let int): return int
            case .double(let double): return double
            }
        }
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }
}
