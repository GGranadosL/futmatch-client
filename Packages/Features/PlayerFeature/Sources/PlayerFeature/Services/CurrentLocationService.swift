import Foundation
import CoreLocation

// MARK: - Current Location Providing

/// One-shot access to the device's current location. Returns nil when the user
/// denies permission, location can't be determined, or the request times out.
protocol CurrentLocationProviding {
    func requestCurrentLocation() async -> CLLocationCoordinate2D?
}

// MARK: - Location Managing

/// Seam over `CLLocationManager` so `CurrentLocationService`'s request state
/// machine can be unit-tested. Events are delivered on the main actor.
@MainActor
protocol LocationManaging: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    /// A fix (non-nil) or a failure (nil).
    var onLocationResult: ((CLLocationCoordinate2D?) -> Void)? { get set }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

// MARK: - Current Location Service

/// Requests When-In-Use authorization (showing the system dialog if not yet
/// determined) and resolves a single coordinate.
///
/// Main-actor isolated so the pending request, its timeout and the
/// CoreLocation callbacks are serialized: every waiter is resumed exactly
/// once, no matter how many callbacks (fix, failure, authorization change,
/// timeout) race to finish it. Callers that arrive while a request is in
/// flight share its result instead of replacing it.
///
/// Shared across ViewModels (see `PlayerDependencyFactory`) so the Matches,
/// Reserved, and Home tabs all reuse the same fix instead of racing
/// independent CLLocationManagers — a fresh GPS fix from a second manager can
/// take noticeably longer than reusing the first one's result.
@MainActor
final class CurrentLocationService: CurrentLocationProviding {
    nonisolated private let makeLocationManager: @MainActor @Sendable () -> LocationManaging
    nonisolated private let authorizationTimeoutNanoseconds: UInt64
    nonisolated private let fixTimeoutNanoseconds: UInt64

    private var locationManager: LocationManaging?
    private var waiters: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private var timeoutTask: Task<Void, Never>?
    private var hasRequestedFix = false
    /// Coordinate from the most recent successful fix, reused by later callers
    /// within the session instead of triggering another GPS round-trip.
    private var cachedCoordinate: CLLocationCoordinate2D?

    /// - Parameters:
    ///   - makeLocationManager: Built lazily on the main actor, on first request.
    ///   - authorizationTimeoutNanoseconds: How long to wait for the user to
    ///     answer the permission dialog before giving up.
    ///   - fixTimeoutNanoseconds: How long to wait for CoreLocation to produce
    ///     a fix once authorized (e.g. simulator without a simulated location).
    nonisolated init(
        makeLocationManager: @escaping @MainActor @Sendable () -> LocationManaging,
        authorizationTimeoutNanoseconds: UInt64 = 60_000_000_000,
        fixTimeoutNanoseconds: UInt64 = 10_000_000_000
    ) {
        self.makeLocationManager = makeLocationManager
        self.authorizationTimeoutNanoseconds = authorizationTimeoutNanoseconds
        self.fixTimeoutNanoseconds = fixTimeoutNanoseconds
    }

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        if let cachedCoordinate { return cachedCoordinate }
        let manager = resolvedLocationManager()
        let status = manager.authorizationStatus
        guard status != .denied && status != .restricted else { return nil }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            // A request is already in flight — share its result.
            guard waiters.count == 1 else { return }

            if status == .notDetermined {
                // requestLocation() is triggered from the authorization callback.
                armTimeout(nanoseconds: authorizationTimeoutNanoseconds)
                manager.requestWhenInUseAuthorization()
            } else {
                requestFix(from: manager)
            }
        }
    }

    // MARK: - Private

    private func resolvedLocationManager() -> LocationManaging {
        if let locationManager { return locationManager }
        let manager = makeLocationManager()
        manager.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
        manager.onLocationResult = { [weak self] coordinate in
            self?.finish(with: coordinate)
        }
        locationManager = manager
        return manager
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard !waiters.isEmpty, let locationManager else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix(from: locationManager)
        case .denied, .restricted:
            finish(with: nil)
        case .notDetermined:
            break // dialog still pending
        @unknown default:
            break
        }
    }

    /// CoreLocation also reports the current authorization when the manager
    /// is created, so this guards against asking for a second fix.
    private func requestFix(from manager: LocationManaging) {
        guard !hasRequestedFix else { return }
        hasRequestedFix = true
        armTimeout(nanoseconds: fixTimeoutNanoseconds)
        manager.requestLocation()
    }

    private func armTimeout(nanoseconds: UInt64) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return // cancelled: the request already finished or re-armed
            }
            self?.finish(with: nil)
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        // Late or duplicate callback for a request that already finished.
        guard !waiters.isEmpty else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        hasRequestedFix = false
        if let coordinate { cachedCoordinate = coordinate }
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: coordinate) }
    }
}

// MARK: - Core Location Manager

/// `LocationManaging` backed by a real `CLLocationManager`. Created on the
/// main actor, so CoreLocation delivers its delegate callbacks on the main
/// thread; they are still hopped explicitly to keep the isolation checked.
@MainActor
final class CoreLocationManager: NSObject, LocationManaging {
    private let manager = CLLocationManager()

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationResult: ((CLLocationCoordinate2D?) -> Void)?

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }
}

extension CoreLocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            self?.onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        DispatchQueue.main.async { [weak self] in
            self?.onLocationResult?(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onLocationResult?(nil)
        }
    }
}
