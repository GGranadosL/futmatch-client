import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import PlayerFeature
import PersistenceFramework
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
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
        #if DEBUG
        print("[🔔 FM-PUSH] Registering for remote notifications at launch (silent)")
        #endif
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        print("[🔔 FM-PUSH] APNs device token registered: \(tokenHex)")
        print("[🔔 FM-PUSH] APNs environment (entitlement): development (sandbox)")
        #endif
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        print("[🔔 FM-PUSH] APNs token handed to Firebase Messaging")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[🔔 FM-PUSH] ❌ Failed to register for remote notifications: \(error)")
        #endif
    }

    // MARK: - Private

    /// Call this after the user has logged in to show the notification permission dialog.
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            #if DEBUG
            print("[🔔 FM-PUSH] Notification authorization — granted: \(granted), error: \(String(describing: error))")
            #endif
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        #if DEBUG
        if let token = fcmToken {
            print("[🔔 FM-PUSH] FCM registration token received: \(token)")
        } else {
            print("[🔔 FM-PUSH] ⚠️ FCM registration token is nil")
        }
        #endif

        guard let fcmToken else { return }

        // Always persist the token so syncFCMTokenIfNeeded() can find it after login.
        do {
            try KeychainManager.shared.save(fcmToken, for: .fcmToken)
            #if DEBUG
            print("[🔔 FM-PUSH] FCM token saved to Keychain ✓")
            #endif
        } catch {
            #if DEBUG
            print("[🔔 FM-PUSH] ❌ Failed to save FCM token to Keychain: \(error)")
            #endif
        }

        // Only sync with server when user is already authenticated.
        guard KeychainManager.shared.isLoggedIn else {
            #if DEBUG
            print("[🔔 FM-PUSH] User not logged in — skipping FCM token sync with server (will sync after login)")
            #endif
            return
        }

        #if DEBUG
        print("[🔔 FM-PUSH] User is logged in — syncing FCM token with server…")
        #endif

        let useCase = PlayerDependencyFactory().makeUpdateFCMTokenUseCase()
        Task {
            do {
                try await useCase.execute(fcmToken: fcmToken)
                #if DEBUG
                print("[🔔 FM-PUSH] FCM token synced with server ✓")
                #endif
            } catch {
                #if DEBUG
                print("[🔔 FM-PUSH] ❌ FCM token sync with server failed: \(error)")
                #endif
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
