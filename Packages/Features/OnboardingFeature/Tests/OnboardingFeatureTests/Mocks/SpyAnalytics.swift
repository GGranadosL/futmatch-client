import SharedModels

final class SpyAnalytics: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    var names: [String] { events.map(\.name) }
    func log(_ event: AnalyticsEvent) { events.append(event) }
}
