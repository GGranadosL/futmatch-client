import Foundation

// MARK: - AdminFeature Localization

enum L10n {
    enum Admin {
        enum ActionCard {
            static var newMatch: String {
                NSLocalizedString("admin.actionCard.newMatch", bundle: .module, comment: "")
            }
            static var newField: String {
                NSLocalizedString("admin.actionCard.newField", bundle: .module, comment: "")
            }
            static var newLocation: String {
                NSLocalizedString("admin.actionCard.newLocation", bundle: .module, comment: "")
            }
        }

        enum Panel {
            static var title: String {
                NSLocalizedString("admin.panel.title", bundle: .module, comment: "")
            }
            static func greeting(_ name: String) -> String {
                String(format: NSLocalizedString("admin.panel.greeting", bundle: .module, comment: ""), name)
            }
        }

        enum Stats {
            static var upcomingMatches: String {
                NSLocalizedString("admin.stats.upcomingMatches", bundle: .module, comment: "")
            }
            static var registeredFields: String {
                NSLocalizedString("admin.stats.registeredFields", bundle: .module, comment: "")
            }
            static var registeredLocations: String {
                NSLocalizedString("admin.stats.registeredLocations", bundle: .module, comment: "")
            }
        }

        enum UpcomingMatches {
            static var title: String {
                NSLocalizedString("admin.upcomingMatches.title", bundle: .module, comment: "")
            }
            static var viewAll: String {
                NSLocalizedString("admin.upcomingMatches.viewAll", bundle: .module, comment: "")
            }
        }
    }

    enum NewField {
        static var title: String {
            NSLocalizedString("newField.title", bundle: .module, comment: "")
        }
        static var save: String {
            NSLocalizedString("newField.save", bundle: .module, comment: "")
        }
        static var fieldName: String {
            NSLocalizedString("newField.fieldName", bundle: .module, comment: "")
        }
        static var capacity: String {
            NSLocalizedString("newField.capacity", bundle: .module, comment: "")
        }
        static var price: String {
            NSLocalizedString("newField.price", bundle: .module, comment: "")
        }
        static var parking: String {
            NSLocalizedString("newField.parking", bundle: .module, comment: "")
        }
        static var description: String {
            NSLocalizedString("newField.description", bundle: .module, comment: "")
        }
        static var extraInfo: String {
            NSLocalizedString("newField.extraInfo", bundle: .module, comment: "")
        }
    }

    enum NewLocation {
        static var title: String {
            NSLocalizedString("newLocation.title", bundle: .module, comment: "")
        }
        static var save: String {
            NSLocalizedString("newLocation.save", bundle: .module, comment: "")
        }
        static var selectCountryAndCity: String {
            NSLocalizedString("newLocation.selectCountryAndCity", bundle: .module, comment: "")
        }
        static var markLocation: String {
            NSLocalizedString("newLocation.markLocation", bundle: .module, comment: "")
        }
        static var searchAddress: String {
            NSLocalizedString("newLocation.searchAddress", bundle: .module, comment: "")
        }
        static var searchPlaceholder: String {
            NSLocalizedString("newLocation.searchPlaceholder", bundle: .module, comment: "")
        }
        static var searching: String {
            NSLocalizedString("newLocation.searching", bundle: .module, comment: "")
        }
        static var locationInfo: String {
            NSLocalizedString("newLocation.locationInfo", bundle: .module, comment: "")
        }
        static var address: String {
            NSLocalizedString("newLocation.address", bundle: .module, comment: "")
        }
        static var latitude: String {
            NSLocalizedString("newLocation.latitude", bundle: .module, comment: "")
        }
        static var longitude: String {
            NSLocalizedString("newLocation.longitude", bundle: .module, comment: "")
        }
        static var addressNotInCity: String {
            NSLocalizedString("newLocation.addressNotInCity", bundle: .module, comment: "")
        }
    }

    enum Locations {
        static var title: String {
            NSLocalizedString("locations.title", bundle: .module, comment: "")
        }
    }

    enum Fields {
        static var title: String {
            NSLocalizedString("fields.title", bundle: .module, comment: "")
        }
    }

    enum EditField {
        static var title: String {
            NSLocalizedString("editField.title", bundle: .module, comment: "")
        }
        static var save: String {
            NSLocalizedString("editField.save", bundle: .module, comment: "")
        }
    }
}
