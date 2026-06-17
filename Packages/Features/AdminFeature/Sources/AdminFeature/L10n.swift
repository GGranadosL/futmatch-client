import Foundation

// MARK: - AdminFeature Localization

enum L10n {
    enum Common {
        static var cancel: String {
            NSLocalizedString("common.cancel", bundle: .module, comment: "")
        }
    }
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

            enum Title {
                static var newMatch: String {
                    NSLocalizedString("admin.actionCard.newMatch.title", bundle: .module, comment: "")
                }
                static var newField: String {
                    NSLocalizedString("admin.actionCard.newField.title", bundle: .module, comment: "")
                }
                static var newLocation: String {
                    NSLocalizedString("admin.actionCard.newLocation.title", bundle: .module, comment: "")
                }
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
        static var exteriorNumber: String {
            NSLocalizedString("newLocation.exteriorNumber", bundle: .module, comment: "")
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

    enum NewMatch {
        static var title: String {
            NSLocalizedString("newMatch.title", bundle: .module, comment: "")
        }
        static var save: String {
            NSLocalizedString("newMatch.save", bundle: .module, comment: "")
        }
        static var saved: String {
            NSLocalizedString("newMatch.saved", bundle: .module, comment: "")
        }

        enum Publish {
            static var title: String {
                NSLocalizedString("newMatch.publish.title", bundle: .module, comment: "")
            }
            static var message: String {
                NSLocalizedString("newMatch.publish.message", bundle: .module, comment: "")
            }
            static var confirm: String {
                NSLocalizedString("newMatch.publish.confirm", bundle: .module, comment: "")
            }
        }

        enum Players {
            static var min: String {
                NSLocalizedString("newMatch.players.min", bundle: .module, comment: "")
            }
            static var max: String {
                NSLocalizedString("newMatch.players.max", bundle: .module, comment: "")
            }
        }

        enum Section {
            enum Location {
                static var title: String {
                    NSLocalizedString("newMatch.section.location", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.location.description", bundle: .module, comment: "")
                }
            }
            enum DateTime {
                static var title: String {
                    NSLocalizedString("newMatch.section.datetime", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.datetime.description", bundle: .module, comment: "")
                }
            }
            enum Players {
                static var title: String {
                    NSLocalizedString("newMatch.section.players", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.players.description", bundle: .module, comment: "")
                }
            }
            enum Cost {
                static var title: String {
                    NSLocalizedString("newMatch.section.cost", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.cost.description", bundle: .module, comment: "")
                }
            }
            enum Gender {
                static var title: String {
                    NSLocalizedString("newMatch.section.gender", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.gender.description", bundle: .module, comment: "")
                }
            }
            enum Level {
                static var title: String {
                    NSLocalizedString("newMatch.section.level", bundle: .module, comment: "")
                }
                static var description: String {
                    NSLocalizedString("newMatch.section.level.description", bundle: .module, comment: "")
                }
            }
        }

        static var fieldLabel: String {
            NSLocalizedString("newMatch.field.label", bundle: .module, comment: "")
        }
        static var dateLabel: String {
            NSLocalizedString("newMatch.date.label", bundle: .module, comment: "")
        }
        static var startTimeLabel: String {
            NSLocalizedString("newMatch.time.start", bundle: .module, comment: "")
        }
        static var endTimeLabel: String {
            NSLocalizedString("newMatch.time.end", bundle: .module, comment: "")
        }
        static var priceLabel: String {
            NSLocalizedString("newMatch.price.label", bundle: .module, comment: "")
        }
        static var genderLabel: String {
            NSLocalizedString("newMatch.gender.label", bundle: .module, comment: "")
        }
        static var levelLabel: String {
            NSLocalizedString("newMatch.level.label", bundle: .module, comment: "")
        }
        static var loadingFields: String {
            NSLocalizedString("newMatch.loadingFields", bundle: .module, comment: "")
        }
    }

    enum Location {
        enum Delete {
            static var title: String {
                NSLocalizedString("location.delete.title", bundle: .module, comment: "")
            }
            static var message: String {
                NSLocalizedString("location.delete.message", bundle: .module, comment: "")
            }
            static var confirm: String {
                NSLocalizedString("location.delete.confirm", bundle: .module, comment: "")
            }
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
        static func rule(_ number: Int) -> String {
            String(format: NSLocalizedString("editField.rule", bundle: .module, comment: ""), number)
        }
        static var addRule: String {
            NSLocalizedString("editField.addRule", bundle: .module, comment: "")
        }
    }

    enum EditLocation {
        static var title: String {
            NSLocalizedString("editLocation.title", bundle: .module, comment: "")
        }
    }

    enum AdminMatches {
        static var title: String {
            NSLocalizedString("adminMatches.title", bundle: .module, comment: "")
        }
        static var heading: String {
            NSLocalizedString("adminMatches.heading", bundle: .module, comment: "")
        }
        static var description: String {
            NSLocalizedString("adminMatches.description", bundle: .module, comment: "")
        }
    }

    enum AdminFields {
        static var heading: String {
            NSLocalizedString("adminFields.heading", bundle: .module, comment: "")
        }
        static var description: String {
            NSLocalizedString("adminFields.description", bundle: .module, comment: "")
        }
    }
}
