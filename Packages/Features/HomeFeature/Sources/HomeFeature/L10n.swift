import Foundation

/// Localized strings for Home
public enum L10n {
    
    // MARK: - Tabs
    public enum Tab {
        public static var home: String {
            NSLocalizedString("home.tab.home", bundle: .module, comment: "")
        }
        public static var matches: String {
            NSLocalizedString("home.tab.matches", bundle: .module, comment: "")
        }
        public static var reserved: String {
            NSLocalizedString("home.tab.reserved", bundle: .module, comment: "")
        }
        public static var profile: String {
            NSLocalizedString("home.tab.profile", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Home
    public static var title: String {
        NSLocalizedString("home.title", bundle: .module, comment: "")
    }
    
    public static func greeting(_ name: String) -> String {
        String(format: NSLocalizedString("home.greeting", bundle: .module, comment: ""), name)
    }
    
    public static var rating: String {
        NSLocalizedString("home.rating", bundle: .module, comment: "")
    }
    
    // MARK: - Next Game
    public enum NextGame {
        public static var title: String {
            NSLocalizedString("home.nextGame.title", bundle: .module, comment: "")
        }
        public static var today: String {
            NSLocalizedString("home.nextGame.today", bundle: .module, comment: "")
        }
        public static var viewDetail: String {
            NSLocalizedString("home.nextGame.viewDetail", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("home.nextGame.empty", bundle: .module, comment: "")
        }
        public static var joinMatch: String {
            NSLocalizedString("home.nextGame.joinMatch", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Suggested Games
    public enum SuggestedGames {
        public static var title: String {
            NSLocalizedString("home.suggestedGames.title", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("home.suggestedGames.empty", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Stats
    public enum Stats {
        public static var title: String {
            NSLocalizedString("home.stats.title", bundle: .module, comment: "")
        }
        public static var played: String {
            NSLocalizedString("home.stats.played", bundle: .module, comment: "")
        }
        public static var won: String {
            NSLocalizedString("home.stats.won", bundle: .module, comment: "")
        }
        public static var mvp: String {
            NSLocalizedString("home.stats.mvp", bundle: .module, comment: "")
        }
    }

    // MARK: - Last Match
    public enum LastMatch {
        public static var title: String {
            NSLocalizedString("home.lastMatch.title", bundle: .module, comment: "")
        }
        public static var win: String {
            NSLocalizedString("home.lastMatch.win", bundle: .module, comment: "")
        }
        public static var loss: String {
            NSLocalizedString("home.lastMatch.loss", bundle: .module, comment: "")
        }
        public static var draw: String {
            NSLocalizedString("home.lastMatch.draw", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("home.lastMatch.empty", bundle: .module, comment: "")
        }
        public static var emptyAction: String {
            NSLocalizedString("home.lastMatch.emptyAction", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Profile
    public enum Profile {
        public static var editProfile: String {
            NSLocalizedString("profile.editProfile", bundle: .module, comment: "")
        }
        public static var statistics: String {
            NSLocalizedString("profile.statistics", bundle: .module, comment: "")
        }
        public static var played: String {
            NSLocalizedString("profile.played", bundle: .module, comment: "")
        }
        public static var won: String {
            NSLocalizedString("profile.won", bundle: .module, comment: "")
        }
        public static var mvp: String {
            NSLocalizedString("profile.mvp", bundle: .module, comment: "")
        }
        public static var totalGoals: String {
            NSLocalizedString("profile.totalGoals", bundle: .module, comment: "")
        }
        public static var performance: String {
            NSLocalizedString("profile.performance", bundle: .module, comment: "")
        }
        public static var playerLevel: String {
            NSLocalizedString("profile.playerLevel", bundle: .module, comment: "")
        }
        public static var logoutTitle: String {
            NSLocalizedString("profile.logoutTitle", bundle: .module, comment: "")
        }
        public static var logoutMessage: String {
            NSLocalizedString("profile.logoutMessage", bundle: .module, comment: "")
        }
        public static var logoutConfirm: String {
            NSLocalizedString("profile.logoutConfirm", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Matches List
    public enum Matches {
        public static var upcoming: String {
            NSLocalizedString("matches.upcoming", bundle: .module, comment: "")
        }
        public static var today: String {
            NSLocalizedString("matches.today", bundle: .module, comment: "")
        }
        public static var tomorrow: String {
            NSLocalizedString("matches.tomorrow", bundle: .module, comment: "")
        }
        public static var teamA: String {
            NSLocalizedString("matches.teamA", bundle: .module, comment: "")
        }
        public static var teamB: String {
            NSLocalizedString("matches.teamB", bundle: .module, comment: "")
        }
        public static func spotsLeft(_ count: Int) -> String {
            String(format: NSLocalizedString("matches.spotsLeft", bundle: .module, comment: ""), count)
        }
        public static var mixed: String {
            NSLocalizedString("matches.mixed", bundle: .module, comment: "")
        }
        public static var noMatchesAvailable: String {
            NSLocalizedString("matches.noMatchesAvailable", bundle: .module, comment: "")
        }
        public static var noMatchesSubtitle: String {
            NSLocalizedString("matches.noMatchesSubtitle", bundle: .module, comment: "")
        }
    }

    // MARK: - Common
    public enum Common {
        public static var retry: String {
            NSLocalizedString("common.retry", bundle: .module, comment: "")
        }
        public static var cancel: String {
            NSLocalizedString("common.cancel", bundle: .module, comment: "")
        }
        public static var ok: String {
            NSLocalizedString("common.ok", bundle: .module, comment: "")
        }
        public static var save: String {
            NSLocalizedString("common.save", bundle: .module, comment: "")
        }
        public static var copied: String {
            NSLocalizedString("common.copied", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Reserved
    public enum Reserved {
        public static var title: String {
            NSLocalizedString("reserved.title", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("reserved.empty", bundle: .module, comment: "")
        }
        public static var emptySubtitle: String {
            NSLocalizedString("reserved.emptySubtitle", bundle: .module, comment: "")
        }
        public static var past: String {
            NSLocalizedString("reserved.past", bundle: .module, comment: "")
        }
        public static var tabUpcoming: String {
            NSLocalizedString("reserved.tab.upcoming", bundle: .module, comment: "")
        }
        public static var tabFinished: String {
            NSLocalizedString("reserved.tab.finished", bundle: .module, comment: "")
        }
        public static var tabCanceled: String {
            NSLocalizedString("reserved.tab.canceled", bundle: .module, comment: "")
        }
        public static var emptyUpcoming: String {
            NSLocalizedString("reserved.empty.upcoming", bundle: .module, comment: "")
        }
        public static var emptyFinished: String {
            NSLocalizedString("reserved.empty.finished", bundle: .module, comment: "")
        }
        public static var emptyCanceled: String {
            NSLocalizedString("reserved.empty.canceled", bundle: .module, comment: "")
        }
    }

    // MARK: - Match Detail
    public enum MatchDetail {
        public static var currentLineup: String {
            NSLocalizedString("matchDetail.currentLineup", bundle: .module, comment: "")
        }
        public static func playerCount(_ current: Int, _ max: Int) -> String {
            String(format: NSLocalizedString("matchDetail.playerCount", bundle: .module, comment: ""), current, max)
        }
        public static func spotsLeft(_ count: Int) -> String {
            String(format: NSLocalizedString("matchDetail.spotsLeft", bundle: .module, comment: ""), count)
        }
        public static var joinSlot: String {
            NSLocalizedString("matchDetail.joinSlot", bundle: .module, comment: "")
        }
        public static var reserved: String {
            NSLocalizedString("matchDetail.reserved", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("matchDetail.empty", bundle: .module, comment: "")
        }
        public static var fieldDetails: String {
            NSLocalizedString("matchDetail.fieldDetails", bundle: .module, comment: "")
        }
        public static var shoeType: String {
            NSLocalizedString("matchDetail.shoeType", bundle: .module, comment: "")
        }
        public static var fieldType: String {
            NSLocalizedString("matchDetail.fieldType", bundle: .module, comment: "")
        }
        public static var parking: String {
            NSLocalizedString("matchDetail.parking", bundle: .module, comment: "")
        }
        public static var extraInfo: String {
            NSLocalizedString("matchDetail.extraInfo", bundle: .module, comment: "")
        }
        public static var yes: String {
            NSLocalizedString("matchDetail.yes", bundle: .module, comment: "")
        }
        public static var no: String {
            NSLocalizedString("matchDetail.no", bundle: .module, comment: "")
        }
        public static var rules: String {
            NSLocalizedString("matchDetail.rules", bundle: .module, comment: "")
        }
        public static var joinMatch: String {
            NSLocalizedString("matchDetail.joinMatch", bundle: .module, comment: "")
        }
        public static var joiningMatch: String {
            NSLocalizedString("matchDetail.joiningMatch", bundle: .module, comment: "")
        }
        public static var loadError: String {
            NSLocalizedString("matchDetail.loadError", bundle: .module, comment: "")
        }
        public static var joinError: String {
            NSLocalizedString("matchDetail.joinError", bundle: .module, comment: "")
        }
        public static var cancelMatch: String {
            NSLocalizedString("matchDetail.cancelMatch", bundle: .module, comment: "")
        }
        public static var cancelMatchConfirmTitle: String {
            NSLocalizedString("matchDetail.cancelMatchConfirmTitle", bundle: .module, comment: "")
        }
        public static var cancelMatchConfirm: String {
            NSLocalizedString("matchDetail.cancelMatchConfirm", bundle: .module, comment: "")
        }
        public static var cancelMatchConfirmMessage: String {
            NSLocalizedString("matchDetail.cancelMatchConfirmMessage", bundle: .module, comment: "")
        }
        public static var cancelMatchError: String {
            NSLocalizedString("matchDetail.cancelMatchError", bundle: .module, comment: "")
        }
        public static var leaveMatch: String {
            NSLocalizedString("matchDetail.leaveMatch", bundle: .module, comment: "")
        }
        public static var leaveMatchConfirmTitle: String {
            NSLocalizedString("matchDetail.leaveMatchConfirmTitle", bundle: .module, comment: "")
        }
        public static var leaveMatchConfirmMessage: String {
            NSLocalizedString("matchDetail.leaveMatchConfirmMessage", bundle: .module, comment: "")
        }
        public static var leaveMatchConfirm: String {
            NSLocalizedString("matchDetail.leaveMatchConfirm", bundle: .module, comment: "")
        }
        public static var leaveMatchError: String {
            NSLocalizedString("matchDetail.leaveMatchError", bundle: .module, comment: "")
        }
        public static var leaveNoRefundTitle: String {
            NSLocalizedString("matchDetail.leaveNoRefundTitle", bundle: .module, comment: "")
        }
        public static var leaveNoRefundMessage: String {
            NSLocalizedString("matchDetail.leaveNoRefundMessage", bundle: .module, comment: "")
        }
        public static var leaveNoRefundConfirm: String {
            NSLocalizedString("matchDetail.leaveNoRefundConfirm", bundle: .module, comment: "")
        }
        public static var leaveNoRefundCancel: String {
            NSLocalizedString("matchDetail.leaveNoRefundCancel", bundle: .module, comment: "")
        }
        public static var leaveSuccessTitle: String {
            NSLocalizedString("matchDetail.leaveSuccessTitle", bundle: .module, comment: "")
        }
        public static var leaveSuccessMessage: String {
            NSLocalizedString("matchDetail.leaveSuccessMessage", bundle: .module, comment: "")
        }
        public static var leaveSuccessUnderstood: String {
            NSLocalizedString("matchDetail.leaveSuccessUnderstood", bundle: .module, comment: "")
        }
        public static var reservationExpiredTitle: String {
            NSLocalizedString("matchDetail.reservationExpiredTitle", bundle: .module, comment: "")
        }
        public static var reservationExpiredMessage: String {
            NSLocalizedString("matchDetail.reservationExpiredMessage", bundle: .module, comment: "")
        }
    }

    // MARK: - Settings
    public enum Settings {
        public static var title: String {
            NSLocalizedString("settings.title", bundle: .module, comment: "")
        }
        public static var paymentMethods: String {
            NSLocalizedString("settings.paymentMethods", bundle: .module, comment: "")
        }
        public static var paymentMethodsDesc: String {
            NSLocalizedString("settings.paymentMethodsDesc", bundle: .module, comment: "")
        }
        public static var paymentHistory: String {
            NSLocalizedString("settings.paymentHistory", bundle: .module, comment: "")
        }
        public static var paymentHistoryDesc: String {
            NSLocalizedString("settings.paymentHistoryDesc", bundle: .module, comment: "")
        }
        public static var help: String {
            NSLocalizedString("settings.help", bundle: .module, comment: "")
        }
        public static var helpDesc: String {
            NSLocalizedString("settings.helpDesc", bundle: .module, comment: "")
        }
        public static var terms: String {
            NSLocalizedString("settings.terms", bundle: .module, comment: "")
        }
        public static var termsDesc: String {
            NSLocalizedString("settings.termsDesc", bundle: .module, comment: "")
        }
        public static var privacy: String {
            NSLocalizedString("settings.privacy", bundle: .module, comment: "")
        }
        public static var privacyDesc: String {
            NSLocalizedString("settings.privacyDesc", bundle: .module, comment: "")
        }
        public static var theme: String {
            NSLocalizedString("settings.theme", bundle: .module, comment: "")
        }
        public static var themeDesc: String {
            NSLocalizedString("settings.themeDesc", bundle: .module, comment: "")
        }
        public static var language: String {
            NSLocalizedString("settings.language", bundle: .module, comment: "")
        }
        public static var languageDesc: String {
            NSLocalizedString("settings.languageDesc", bundle: .module, comment: "")
        }
        public static var logout: String {
            NSLocalizedString("settings.logout", bundle: .module, comment: "")
        }
        public static var deleteAccount: String {
            NSLocalizedString("settings.deleteAccount", bundle: .module, comment: "")
        }
        public static var deleteAccountDesc: String {
            NSLocalizedString("settings.deleteAccountDesc", bundle: .module, comment: "")
        }
    }

    // MARK: - Edit Profile
    public enum EditProfile {
        public static var title: String {
            NSLocalizedString("editProfile.title", bundle: .module, comment: "")
        }
        public static var description: String {
            NSLocalizedString("editProfile.description", bundle: .module, comment: "")
        }
        public static var editAvatar: String {
            NSLocalizedString("editProfile.editAvatar", bundle: .module, comment: "")
        }
        public static var name: String {
            NSLocalizedString("editProfile.name", bundle: .module, comment: "")
        }
        public static var email: String {
            NSLocalizedString("editProfile.email", bundle: .module, comment: "")
        }
        public static var country: String {
            NSLocalizedString("editProfile.country", bundle: .module, comment: "")
        }
        public static var gender: String {
            NSLocalizedString("editProfile.gender", bundle: .module, comment: "")
        }
        public static var mainPosition: String {
            NSLocalizedString("editProfile.mainPosition", bundle: .module, comment: "")
        }
        public static var takePhoto: String {
            NSLocalizedString("editProfile.takePhoto", bundle: .module, comment: "")
        }
        public static var chooseFromGallery: String {
            NSLocalizedString("editProfile.chooseFromGallery", bundle: .module, comment: "")
        }
        public static var cancel: String {
            NSLocalizedString("editProfile.cancel", bundle: .module, comment: "")
        }
        public static var uploadError: String {
            NSLocalizedString("editProfile.uploadError", bundle: .module, comment: "")
        }
        public static var uploadSuccess: String {
            NSLocalizedString("editProfile.uploadSuccess", bundle: .module, comment: "")
        }
        public static var editName: String {
            NSLocalizedString("editProfile.editName", bundle: .module, comment: "")
        }
        public static var editNameDesc: String {
            NSLocalizedString("editProfile.editNameDesc", bundle: .module, comment: "")
        }
        public static var firstName: String {
            NSLocalizedString("editProfile.firstName", bundle: .module, comment: "")
        }
        public static var lastName: String {
            NSLocalizedString("editProfile.lastName", bundle: .module, comment: "")
        }
        public static var editCountry: String {
            NSLocalizedString("editProfile.editCountry", bundle: .module, comment: "")
        }
        public static var editCountryDesc: String {
            NSLocalizedString("editProfile.editCountryDesc", bundle: .module, comment: "")
        }
        public static var searchCountry: String {
            NSLocalizedString("editProfile.searchCountry", bundle: .module, comment: "")
        }
        public static var editGender: String {
            NSLocalizedString("editProfile.editGender", bundle: .module, comment: "")
        }
        public static var editGenderDesc: String {
            NSLocalizedString("editProfile.editGenderDesc", bundle: .module, comment: "")
        }
        public static var editPosition: String {
            NSLocalizedString("editProfile.editPosition", bundle: .module, comment: "")
        }
        public static var editPositionDesc: String {
            NSLocalizedString("editProfile.editPositionDesc", bundle: .module, comment: "")
        }
    }

    // MARK: - Join Alert
    public enum JoinAlert {
        public static var title: String {
            NSLocalizedString("matchDetail.join.alert.title", bundle: .module, comment: "")
        }
        public static var message: String {
            NSLocalizedString("matchDetail.join.alert.message", bundle: .module, comment: "")
        }
        public static var payNow: String {
            NSLocalizedString("matchDetail.join.alert.payNow", bundle: .module, comment: "")
        }
        public static var payLater: String {
            NSLocalizedString("matchDetail.join.alert.payLater", bundle: .module, comment: "")
        }
        public static func countdown(_ time: String) -> String {
            String(format: NSLocalizedString("matchDetail.join.alert.countdown", bundle: .module, comment: ""), time)
        }
        public static var pay: String {
            NSLocalizedString("matchDetail.join.alert.pay", bundle: .module, comment: "")
        }
    }

    // MARK: - Error Overlay
    public enum ErrorOverlay {
        public static var title: String {
            NSLocalizedString("error.overlay.title", bundle: .module, comment: "")
        }
        public static var message: String {
            NSLocalizedString("error.overlay.message", bundle: .module, comment: "")
        }
        public static var understood: String {
            NSLocalizedString("error.overlay.understood", bundle: .module, comment: "")
        }
    }

    // MARK: - Payment
    public enum Payment {
        public static var errorTitle: String {
            NSLocalizedString("payment.errorTitle", bundle: .module, comment: "")
        }
        public static var successTitle: String {
            NSLocalizedString("payment.successTitle", bundle: .module, comment: "")
        }
        public static var successMessage: String {
            NSLocalizedString("payment.successMessage", bundle: .module, comment: "")
        }
        public static var understood: String {
            NSLocalizedString("payment.understood", bundle: .module, comment: "")
        }
    }

    // MARK: - Payment History
    public enum PaymentHistory {
        public static var title: String {
            NSLocalizedString("paymentHistory.title", bundle: .module, comment: "")
        }
        public static var sectionTitle: String {
            NSLocalizedString("paymentHistory.sectionTitle", bundle: .module, comment: "")
        }
        public static var empty: String {
            NSLocalizedString("paymentHistory.empty", bundle: .module, comment: "")
        }
        public static var card: String {
            NSLocalizedString("paymentHistory.card", bundle: .module, comment: "")
        }
        public static var columnDate: String {
            NSLocalizedString("paymentHistory.columnDate", bundle: .module, comment: "")
        }
        public static var columnAmount: String {
            NSLocalizedString("paymentHistory.columnAmount", bundle: .module, comment: "")
        }
        public static var columnStatus: String {
            NSLocalizedString("paymentHistory.columnStatus", bundle: .module, comment: "")
        }
        public static var columnTransactionId: String {
            NSLocalizedString("paymentHistory.columnTransactionId", bundle: .module, comment: "")
        }
        public static var columnCard: String {
            NSLocalizedString("paymentHistory.columnCard", bundle: .module, comment: "")
        }
        public static var statusSuccess: String {
            NSLocalizedString("paymentHistory.statusSuccess", bundle: .module, comment: "")
        }
        public static var statusFailed: String {
            NSLocalizedString("paymentHistory.statusFailed", bundle: .module, comment: "")
        }
        public static var statusCanceled: String {
            NSLocalizedString("paymentHistory.statusCanceled", bundle: .module, comment: "")
        }
        public static var statusPending: String {
            NSLocalizedString("paymentHistory.statusPending", bundle: .module, comment: "")
        }
        public static var statusRefunded: String {
            NSLocalizedString("paymentHistory.statusRefunded", bundle: .module, comment: "")
        }
    }
}
