import Foundation

// MARK: - Admin users

extension L10n {
    enum AdminUsers {
        static var dashboardAction: String {
            NSLocalizedString("adminUsers.dashboardAction", bundle: .module, comment: "")
        }
        static var title: String {
            NSLocalizedString("adminUsers.title", bundle: .module, comment: "")
        }
        static var profileTitle: String {
            NSLocalizedString("adminUsers.profileTitle", bundle: .module, comment: "")
        }
        static func registeredCount(_ a0: Int) -> String {
            String(format: NSLocalizedString("adminUsers.registeredCount", bundle: .module, comment: ""), a0)
        }
        static var searchPlaceholder: String {
            NSLocalizedString("adminUsers.searchPlaceholder", bundle: .module, comment: "")
        }
        static var openSearch: String {
            NSLocalizedString("adminUsers.openSearch", bundle: .module, comment: "")
        }
        static var closeSearch: String {
            NSLocalizedString("adminUsers.closeSearch", bundle: .module, comment: "")
        }
        static var clearSearch: String {
            NSLocalizedString("adminUsers.clearSearch", bundle: .module, comment: "")
        }
        static func searchResults(_ a0: Int, _ a1: Int) -> String {
            String(format: NSLocalizedString("adminUsers.searchResults", bundle: .module, comment: ""), a0, a1)
        }
        static var noResults: String {
            NSLocalizedString("adminUsers.noResults", bundle: .module, comment: "")
        }
        static var searchScope: String {
            NSLocalizedString("adminUsers.searchScope", bundle: .module, comment: "")
        }
        static var emptyRole: String {
            NSLocalizedString("adminUsers.emptyRole", bundle: .module, comment: "")
        }
        static var loadError: String {
            NSLocalizedString("adminUsers.loadError", bundle: .module, comment: "")
        }
        static var unnamed: String {
            NSLocalizedString("adminUsers.unnamed", bundle: .module, comment: "")
        }
        static var newBadge: String {
            NSLocalizedString("adminUsers.newBadge", bundle: .module, comment: "")
        }
        static var tabAdmins: String {
            NSLocalizedString("adminUsers.tab.admins", bundle: .module, comment: "")
        }
        static var tabOrganizers: String {
            NSLocalizedString("adminUsers.tab.organizers", bundle: .module, comment: "")
        }
        static var tabPlayers: String {
            NSLocalizedString("adminUsers.tab.players", bundle: .module, comment: "")
        }
        static var roleAdmin: String {
            NSLocalizedString("adminUsers.role.admin", bundle: .module, comment: "")
        }
        static var roleOrganizer: String {
            NSLocalizedString("adminUsers.role.organizer", bundle: .module, comment: "")
        }
        static var rolePlayer: String {
            NSLocalizedString("adminUsers.role.player", bundle: .module, comment: "")
        }
        static var statusActive: String {
            NSLocalizedString("adminUsers.status.active", bundle: .module, comment: "")
        }
        static var statusBlocked: String {
            NSLocalizedString("adminUsers.status.blocked", bundle: .module, comment: "")
        }
        static var statusSuspended: String {
            NSLocalizedString("adminUsers.status.suspended", bundle: .module, comment: "")
        }
        static var unknown: String {
            NSLocalizedString("adminUsers.unknown", bundle: .module, comment: "")
        }
        static var unavailable: String {
            NSLocalizedString("adminUsers.unavailable", bundle: .module, comment: "")
        }
        static var manageAccess: String {
            NSLocalizedString("adminUsers.manageAccess", bundle: .module, comment: "")
        }
        static var manageAccessDescription: String {
            NSLocalizedString("adminUsers.manageAccessDescription", bundle: .module, comment: "")
        }
        static var roleLabel: String {
            NSLocalizedString("adminUsers.roleLabel", bundle: .module, comment: "")
        }
        static var statusLabel: String {
            NSLocalizedString("adminUsers.statusLabel", bundle: .module, comment: "")
        }
        static var sessionsWarning: String {
            NSLocalizedString("adminUsers.sessionsWarning", bundle: .module, comment: "")
        }
        static var saveChanges: String {
            NSLocalizedString("adminUsers.saveChanges", bundle: .module, comment: "")
        }
        static var accessSaved: String {
            NSLocalizedString("adminUsers.accessSaved", bundle: .module, comment: "")
        }
        static var confirmAccessTitle: String {
            NSLocalizedString("adminUsers.confirmAccessTitle", bundle: .module, comment: "")
        }
        static var confirmAccessMessage: String {
            NSLocalizedString("adminUsers.confirmAccessMessage", bundle: .module, comment: "")
        }
        static var selfAccessNote: String {
            NSLocalizedString("adminUsers.selfAccessNote", bundle: .module, comment: "")
        }
        static var activity: String {
            NSLocalizedString("adminUsers.activity", bundle: .module, comment: "")
        }
        static var upcomingMatches: String {
            NSLocalizedString("adminUsers.upcomingMatches", bundle: .module, comment: "")
        }
        static var completedMatches: String {
            NSLocalizedString("adminUsers.completedMatches", bundle: .module, comment: "")
        }
        static var activeSessions: String {
            NSLocalizedString("adminUsers.activeSessions", bundle: .module, comment: "")
        }
        static var account: String {
            NSLocalizedString("adminUsers.account", bundle: .module, comment: "")
        }
        static var email: String {
            NSLocalizedString("adminUsers.email", bundle: .module, comment: "")
        }
        static var phone: String {
            NSLocalizedString("adminUsers.phone", bundle: .module, comment: "")
        }
        static var emailVerified: String {
            NSLocalizedString("adminUsers.emailVerified", bundle: .module, comment: "")
        }
        static var yes: String {
            NSLocalizedString("adminUsers.yes", bundle: .module, comment: "")
        }
        static var no: String {
            NSLocalizedString("adminUsers.no", bundle: .module, comment: "")
        }
        static var memberSince: String {
            NSLocalizedString("adminUsers.memberSince", bundle: .module, comment: "")
        }
        static var security: String {
            NSLocalizedString("adminUsers.security", bundle: .module, comment: "")
        }
        static var failedAttempts: String {
            NSLocalizedString("adminUsers.failedAttempts", bundle: .module, comment: "")
        }
        static var lockedUntil: String {
            NSLocalizedString("adminUsers.lockedUntil", bundle: .module, comment: "")
        }
        static var devices: String {
            NSLocalizedString("adminUsers.devices", bundle: .module, comment: "")
        }
        static func devicesCount(_ a0: Int) -> String {
            String(format: NSLocalizedString("adminUsers.devicesCount", bundle: .module, comment: ""), a0)
        }
        static var noDevices: String {
            NSLocalizedString("adminUsers.noDevices", bundle: .module, comment: "")
        }
        static var unnamedDevice: String {
            NSLocalizedString("adminUsers.unnamedDevice", bundle: .module, comment: "")
        }
        static func lastUsed(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.lastUsed", bundle: .module, comment: ""), a0)
        }
        static func osVersion(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.osVersion", bundle: .module, comment: ""), a0)
        }
        static func appVersion(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.appVersion", bundle: .module, comment: ""), a0)
        }
        static var platformIOS: String {
            NSLocalizedString("adminUsers.platform.ios", bundle: .module, comment: "")
        }
        static var platformAndroid: String {
            NSLocalizedString("adminUsers.platform.android", bundle: .module, comment: "")
        }
        static var platformDesktop: String {
            NSLocalizedString("adminUsers.platform.desktop", bundle: .module, comment: "")
        }
        static var platformWeb: String {
            NSLocalizedString("adminUsers.platform.web", bundle: .module, comment: "")
        }
        static var deviceActive: String {
            NSLocalizedString("adminUsers.device.active", bundle: .module, comment: "")
        }
        static var deviceInactive: String {
            NSLocalizedString("adminUsers.device.inactive", bundle: .module, comment: "")
        }
        static var deviceTrusted: String {
            NSLocalizedString("adminUsers.device.trusted", bundle: .module, comment: "")
        }
        static var deviceUntrusted: String {
            NSLocalizedString("adminUsers.device.untrusted", bundle: .module, comment: "")
        }
        static var payments: String {
            NSLocalizedString("adminUsers.payments", bundle: .module, comment: "")
        }
        static var paymentsSubtitle: String {
            NSLocalizedString("adminUsers.paymentsSubtitle", bundle: .module, comment: "")
        }
        static func paymentsCount(_ a0: Int) -> String {
            String(format: NSLocalizedString("adminUsers.paymentsCount", bundle: .module, comment: ""), a0)
        }
        static var noPayments: String {
            NSLocalizedString("adminUsers.noPayments", bundle: .module, comment: "")
        }
        static func paymentMatchDate(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.payment.matchDate", bundle: .module, comment: ""), a0)
        }
        static func paymentPaidDate(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.payment.paidDate", bundle: .module, comment: ""), a0)
        }
        static func paymentRefundedDate(_ a0: String) -> String {
            String(format: NSLocalizedString("adminUsers.payment.refundedDate", bundle: .module, comment: ""), a0)
        }
        static var paymentMethodUnavailable: String {
            NSLocalizedString("adminUsers.payment.methodUnavailable", bundle: .module, comment: "")
        }
        static var paymentUnknownField: String {
            NSLocalizedString("adminUsers.payment.unknownField", bundle: .module, comment: "")
        }
        static var paymentCreated: String {
            NSLocalizedString("adminUsers.payment.status.created", bundle: .module, comment: "")
        }
        static var paymentAuthorized: String {
            NSLocalizedString("adminUsers.payment.status.authorized", bundle: .module, comment: "")
        }
        static var paymentSucceeded: String {
            NSLocalizedString("adminUsers.payment.status.succeeded", bundle: .module, comment: "")
        }
        static var paymentFailed: String {
            NSLocalizedString("adminUsers.payment.status.failed", bundle: .module, comment: "")
        }
        static var paymentCanceled: String {
            NSLocalizedString("adminUsers.payment.status.canceled", bundle: .module, comment: "")
        }
        static var paymentRefunded: String {
            NSLocalizedString("adminUsers.payment.status.refunded", bundle: .module, comment: "")
        }
        static func cardDescription(_ a0: String, _ a1: String) -> String {
            String(format: NSLocalizedString("adminUsers.payment.card", bundle: .module, comment: ""), a0, a1)
        }
    }
}
