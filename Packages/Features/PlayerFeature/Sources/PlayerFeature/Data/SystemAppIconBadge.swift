import UIKit
import UserNotifications

// MARK: - System App Icon Badge

/// Writes the app icon badge through the system. Zero removes the badge.
struct SystemAppIconBadge: AppIconBadgeProtocol {

    func setCount(_ count: Int) {
        let count = max(0, count)
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
}
