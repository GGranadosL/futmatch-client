import Foundation
import CoreLocation

// MARK: - Current Location Providing

/// One-shot access to the device's current location. Returns nil when the user
/// denies permission, location can't be determined, or the request times out.
protocol CurrentLocationProviding {
    func requestCurrentLocation() async -> CLLocationCoordinate2D?
}

// MARK: - Current Location Service

/// CLLocationManager wrapper that requests When-In-Use authorization (showing
/// the system dialog if not yet determined) and resolves a single coordinate.
/// Shared across ViewModels (see `PlayerDependencyFactory`) so the Matches,
/// Reserved, and Home tabs all resolve the same fix instead of racing
/// independent CLLocationManagers — a fresh GPS fix from a second manager can
/// take noticeably longer than reusing the first one's result.
final class CurrentLocationService: NSObject, CurrentLocationProviding {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timeoutTask: Task<Void, Never>?
    /// Coordinate from the most recent successful fix, reused by later callers
    /// within the session instead of triggering another GPS round-trip.
    private var cachedCoordinate: CLLocationCoordinate2D?
    /// In-flight request, so overlapping callers (e.g. two tabs loading at
    /// once) await the same resolution instead of stepping on each other's
    /// delegate callbacks.
    private var inFlightTask: Task<CLLocationCoordinate2D?, Never>?

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        if let cachedCoordinate { return cachedCoordinate }
        if let inFlightTask { return await inFlightTask.value }

        let task = Task { await resolveCurrentLocation() }
        inFlightTask = task
        let result = await task.value
        inFlightTask = nil
        return result
    }

    private func resolveCurrentLocation() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        guard status != .denied && status != .restricted else { return nil }

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            // Don't hang forever if CoreLocation never answers (e.g. simulator
            // without a simulated location) — the caller falls back to defaults.
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self?.finish(with: nil)
            }

            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
                // requestLocation() is triggered from the authorization callback.
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let coordinate { cachedCoordinate = coordinate }
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension CurrentLocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: nil)
        case .notDetermined:
            break // dialog still pending
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.first?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }
}
