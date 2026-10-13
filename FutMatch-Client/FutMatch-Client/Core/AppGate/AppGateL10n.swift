import Foundation

enum AppGateL10n {
    enum Maintenance {
        static var exitApp: String {
            NSLocalizedString("appgate.maintenance.exit_app", comment: "")
        }

        static var defaultTitle: String {
            NSLocalizedString("appgate.maintenance.default_title", comment: "")
        }
    }

    enum MandatoryUpdate {
        static var defaultMessage: String {
            NSLocalizedString("appgate.mandatory_update.default_message", comment: "")
        }
    }

    enum SoftUpdate {
        static var defaultMessage: String {
            NSLocalizedString("appgate.soft_update.default_message", comment: "")
        }
    }
}
