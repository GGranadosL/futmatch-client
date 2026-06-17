import Foundation
import DeviceCheck
import FirebaseCore
import FirebaseAppCheck

// MARK: - App Check Provider Factory

/// Chooses the right App Check attestation provider per build/device:
///
/// - **DEBUG builds (incl. simulator):** `AppCheckDebugProvider`. On first run it
///   prints a debug token to the console — register it in the Firebase console
///   under App Check ▸ Apps ▸ Manage debug tokens so requests are accepted.
/// - **Release on iOS 14+ devices with Secure Enclave (A12+):** `AppAttestProvider`
///   — matches the "App Attest" provider you configured in the Firebase console.
/// - **Release on older devices:** `DeviceCheckProvider` as a fallback — matches
///   the "DeviceCheck" provider in the console.
///
/// Install this **before** `FirebaseApp.configure()`.
final class FutMatchAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // Debug builds and the simulator cannot use App Attest / DeviceCheck.
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *), DCAppAttestService.shared.isSupported {
            return AppAttestProvider(app: app)
        }
        // Fallback for devices without App Attest support (pre-A12 / iOS 13).
        return DeviceCheckProvider(app: app)
        #endif
    }
}
