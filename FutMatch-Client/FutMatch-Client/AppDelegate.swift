import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import HomeFeature
import PersistenceFramework
import IQKeyboardManagerSwift

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[AppDelegate] Failed to register for remote notifications: \(error)")
        #endif
    }

    // MARK: - Private

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
#if DEBUG
        print("[FCM] didReceiveRegistrationToken: \(fcmToken)")
#endif
        // Only sync with server when user is already authenticated.
        // During the login/signup flow the token is persisted via saveAuthTokens.
        guard KeychainManager.shared.isLoggedIn else {
#if DEBUG
            print("[FCM] Not logged in, skipping FCM sync")
#endif
            return
        }

        let useCase = HomeDependencyFactory().makeUpdateFCMTokenUseCase()
        Task {
#if DEBUG
            print("[FCM] Syncing FCM token with backend...")
#endif
            do {
                try await useCase.execute(fcmToken: fcmToken)
#if DEBUG
                print("[FCM] FCM token sync completed")
#endif
            } catch {
#if DEBUG
                print("[FCM] FCM token sync failed: \(error)")
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
