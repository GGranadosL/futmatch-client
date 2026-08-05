import UIKit
import UserNotifications
import OSLog
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging
import PlayerFeature
import PersistenceFramework
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
#if DEBUG
import Pulse
import PulseUI
import SwiftUI
#endif

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    let adminRemoteConfig = AdminRemoteConfigRepository()
    let legalLinksRemoteConfig = LegalLinksRemoteConfigRepository()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // App Check must be installed BEFORE FirebaseApp.configure() so the very
        // first Firebase request carries an attestation token. Uses App Attest on
        // capable devices, DeviceCheck as fallback, and a debug provider in DEBUG.
        // Gated by Config.isAppCheckEnabled (off in DEBUG until a debug token is
        // registered) so a failing token exchange can't stall Firebase at launch.
        if Config.isAppCheckEnabled {
            #if DEBUG
            // Pin a fixed debug token so it only needs to be registered in Firebase console once.
            // Register this UUID at: Firebase console → App Check → Apps → [app] → Manage debug tokens
            setenv("FIRAAppCheckDebugToken", "D2B4A26E-8370-4485-9C52-7A47AE44FEB2", 1)
            #endif
            AppCheck.setAppCheckProviderFactory(FutMatchAppCheckProviderFactory())
        }
        FirebaseApp.configure()
        Task { await adminRemoteConfig.fetchAndActivate() }
        Task { await legalLinksRemoteConfig.fetchAndActivate() }
        #if DEBUG
        print("[🔔 FM-PUSH] FirebaseApp.configure() called")
        #endif
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        // Register for remote notifications silently at launch to get the APNs token
        // early — this does NOT show a permission dialog to the user.
        // The actual permission request (dialog) is deferred until after login.
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - Data-only Push (regional matches refresh / in-app notifications)

    /// Handles data-only pushes. Regional `matches_updated` payloads are routed
    /// into the in-app notification that auto-refreshes the matches feed.
    /// Any other remote push is treated as a signal that a new in-app
    /// notification was created server-side (there's no distinguishing `type`
    /// for those yet), and routed to refresh the notifications feed instead.
    /// Fires in foreground and background (for `content-available` messages).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let isMatchesPush = MatchPushRouter.handleRemoteNotification(userInfo)
        if !isMatchesPush {
            InAppNotificationPushRouter.handleRemoteNotification(userInfo)
        }
        return .newData
    }

    // MARK: - Match Topics

    /// Subscribes to the regional matches topic so the app receives
    /// `matches_updated` auto-refresh pushes. Safe to call repeatedly (FCM
    /// de-dupes). Call once an authenticated session is ready.
    func subscribeToMatchUpdates() {
        Messaging.messaging().subscribe(toTopic: MatchRegion.default.topic)
    }

    /// Unsubscribes from the regional matches topic (called on logout).
    func unsubscribeFromMatchUpdates() {
        Messaging.messaging().unsubscribe(fromTopic: MatchRegion.default.topic)
    }

    // MARK: - Private

    /// Call this after the user has logged in to show the notification permission dialog.
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }

        // Always persist the token so the next login's syncFCMTokenIfNeeded() has a
        // fallback cached value even if fetching a fresh one from Firebase fails.
        try? KeychainManager.shared.save(fcmToken, for: .fcmToken)

        // Only sync with server when user is already authenticated — covers the case
        // where the token rotates mid-session (rare, e.g. token invalidation/refresh).
        guard KeychainManager.shared.isLoggedIn else { return }

        let useCase = PlayerDependencyFactory().makeUpdateFCMTokenUseCase()
        Task {
            do {
                try await useCase.execute(fcmToken: fcmToken)
            } catch {
                let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "FCM")
                logger.error("FCM token sync (delegate refresh) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

#if DEBUG
// MARK: - Shake to show Pulse console

extension UIWindow {

    /// Shows the Pulse network/log console whenever the device is shaken (Debug only).
    /// Simulator shortcut: Device ▸ Shake, or ⌃⌘Z.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            let console = UIHostingController(rootView: ConsoleView())
            topmostViewController?.present(console, animated: true)
        }
    }

    private var topmostViewController: UIViewController? {
        var vc = rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }
}
#endif
