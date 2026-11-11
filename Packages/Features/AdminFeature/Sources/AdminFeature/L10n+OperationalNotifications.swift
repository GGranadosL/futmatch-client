import Foundation

// MARK: - Operational notifications

extension L10n {
    enum OperationalNotifications {
        static var title: String {
            NSLocalizedString("operationalNotifications.title", bundle: .module, comment: "")
        }
        static var empty: String {
            NSLocalizedString("operationalNotifications.empty", bundle: .module, comment: "")
        }
        static var today: String {
            NSLocalizedString("operationalNotifications.today", bundle: .module, comment: "")
        }
        static var yesterday: String {
            NSLocalizedString("operationalNotifications.yesterday", bundle: .module, comment: "")
        }
        static var open: String {
            NSLocalizedString("operationalNotifications.open", bundle: .module, comment: "")
        }
        static func unreadCount(_ a0: Int) -> String {
            String(format: NSLocalizedString("operationalNotifications.unreadCount", bundle: .module, comment: ""), a0)
        }
        static var delete: String {
            NSLocalizedString("operationalNotifications.delete", bundle: .module, comment: "")
        }
        static var matchUnavailable: String {
            NSLocalizedString("operationalNotifications.matchUnavailable", bundle: .module, comment: "")
        }
        static var loadError: String {
            NSLocalizedString("operationalNotifications.loadError", bundle: .module, comment: "")
        }
        static var pendingNotices: String {
            NSLocalizedString("operationalNotifications.pendingNotices", bundle: .module, comment: "")
        }
    }
}
