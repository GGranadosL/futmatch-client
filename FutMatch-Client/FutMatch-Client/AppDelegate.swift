import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging
import PlayerFeature
import PersistenceFramework
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    let adminRemoteConfig = AdminRemoteConfigRepository()

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
            AppCheck.setAppCheckProviderFactory(FutMatchAppCheckProviderFactory())
        }
        FirebaseApp.configure()
        Task { await adminRemoteConfig.fetchAndActivate() }
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

    // MARK: - Data-only Push (regional matches refresh)

    /// Handles data-only pushes. Regional `matches_updated` payloads are routed
    /// into the in-app notification that auto-refreshes the matches feed.
    /// Fires in foreground and background (for `content-available` messages).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let handled = MatchPushRouter.handleRemoteNotification(userInfo)
        return handled ? .newData : .noData
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

        // Always persist the token so syncFCMTokenIfNeeded() can find it after login.
        try? KeychainManager.shared.save(fcmToken, for: .fcmToken)

        // Only sync with server when user is already authenticated.
        guard KeychainManager.shared.isLoggedIn else { return }

        let useCase = PlayerDependencyFactory().makeUpdateFCMTokenUseCase()
        Task {
            try? await useCase.execute(fcmToken: fcmToken)
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
