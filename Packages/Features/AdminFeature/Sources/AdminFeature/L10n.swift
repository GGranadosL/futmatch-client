import Foundation

// MARK: - AdminFeature Localization

enum L10n {
    enum Common {
        static var cancel: String {
            NSLocalizedString("common.cancel", bundle: .module, comment: "")
        }
        static var errorTitle: String {
            NSLocalizedString("common.errorTitle", bundle: .module, comment: "")
        }
        static var retry: String {
            NSLocalizedString("common.retry", bundle: .module, comment: "")
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
        static var tabUpcoming: String {
            NSLocalizedString("adminMatches.tabUpcoming", bundle: .module, comment: "")
        }
        static var tabFinished: String {
            NSLocalizedString("adminMatches.tabFinished", bundle: .module, comment: "")
        }
        static var tabCanceled: String {
            NSLocalizedString("adminMatches.tabCanceled", bundle: .module, comment: "")
        }
        static var sectionToday: String {
            NSLocalizedString("adminMatches.sectionToday", bundle: .module, comment: "")
        }
        static var sectionTomorrow: String {
            NSLocalizedString("adminMatches.sectionTomorrow", bundle: .module, comment: "")
        }
        static var emptyAll: String {
            NSLocalizedString("adminMatches.emptyAll", bundle: .module, comment: "")
        }
        static var emptyUpcoming: String {
            NSLocalizedString("adminMatches.emptyUpcoming", bundle: .module, comment: "")
        }
        static var emptyFinished: String {
            NSLocalizedString("adminMatches.emptyFinished", bundle: .module, comment: "")
        }
        static var emptyCanceled: String {
            NSLocalizedString("adminMatches.emptyCanceled", bundle: .module, comment: "")
        }
        static var incomplete: String {
            NSLocalizedString("adminMatches.incomplete", bundle: .module, comment: "")
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

    enum EditMatch {
        static var title: String {
            NSLocalizedString("editMatch.title", bundle: .module, comment: "")
        }
        static var saveChanges: String {
            NSLocalizedString("editMatch.saveChanges", bundle: .module, comment: "")
        }
        static var confirmTitle: String {
            NSLocalizedString("editMatch.confirmTitle", bundle: .module, comment: "")
        }
        static var confirmMessage: String {
            NSLocalizedString("editMatch.confirmMessage", bundle: .module, comment: "")
        }
        static var confirmButton: String {
            NSLocalizedString("editMatch.confirmButton", bundle: .module, comment: "")
        }
        static var successMessage: String {
            NSLocalizedString("editMatch.successMessage", bundle: .module, comment: "")
        }
    }

    enum CancelMatch {
        static var title: String {
            NSLocalizedString("cancelMatch.title", bundle: .module, comment: "")
        }
        static var noPayMessage: String {
            NSLocalizedString("cancelMatch.noPayMessage", bundle: .module, comment: "")
        }
        static var withPayMessage: String {
            NSLocalizedString("cancelMatch.withPayMessage", bundle: .module, comment: "")
        }
        static var confirmButton: String {
            NSLocalizedString("cancelMatch.confirmButton", bundle: .module, comment: "")
        }
        static var backButton: String {
            NSLocalizedString("cancelMatch.backButton", bundle: .module, comment: "")
        }
        static var reasonTitle: String {
            NSLocalizedString("cancelMatch.reasonTitle", bundle: .module, comment: "")
        }
        static var reasonSubtitle: String {
            NSLocalizedString("cancelMatch.reasonSubtitle", bundle: .module, comment: "")
        }
        static var reasonMinPlayers: String {
            NSLocalizedString("cancelMatch.reasonMinPlayers", bundle: .module, comment: "")
        }
        static var reasonWeather: String {
            NSLocalizedString("cancelMatch.reasonWeather", bundle: .module, comment: "")
        }
        static var reasonFieldUnavailable: String {
            NSLocalizedString("cancelMatch.reasonFieldUnavailable", bundle: .module, comment: "")
        }
        static var reasonOther: String {
            NSLocalizedString("cancelMatch.reasonOther", bundle: .module, comment: "")
        }
        static var reasonOtherLabel: String {
            NSLocalizedString("cancelMatch.reasonOtherLabel", bundle: .module, comment: "")
        }
        static var invalidReason: String {
            NSLocalizedString("cancelMatch.invalidReason", bundle: .module, comment: "")
        }
        static var canceledSuccess: String {
            NSLocalizedString("cancelMatch.canceledSuccess", bundle: .module, comment: "")
        }
    }

    enum MatchSupervision {
        static var title: String {
            NSLocalizedString("matchSupervision.title", bundle: .module, comment: "")
        }
        static var bestPlayer: String {
            NSLocalizedString("matchSupervision.bestPlayer", bundle: .module, comment: "")
        }
        static var bestPlayerPlaceholder: String {
            NSLocalizedString("matchSupervision.bestPlayerPlaceholder", bundle: .module, comment: "")
        }
        static var goalsPerPlayer: String {
            NSLocalizedString("matchSupervision.goalsPerPlayer", bundle: .module, comment: "")
        }
        static var externalPlayer: String {
            NSLocalizedString("matchSupervision.externalPlayer", bundle: .module, comment: "")
        }
        static var finalizeButton: String {
            NSLocalizedString("matchSupervision.finalizeButton", bundle: .module, comment: "")
        }
        static var finalizeTitle: String {
            NSLocalizedString("matchSupervision.finalizeTitle", bundle: .module, comment: "")
        }
        static var bestPlayerRequired: String {
            NSLocalizedString("matchSupervision.bestPlayerRequired", bundle: .module, comment: "")
        }
        static var completedSuccess: String {
            NSLocalizedString("matchSupervision.completedSuccess", bundle: .module, comment: "")
        }
        static var playersLoadError: String {
            NSLocalizedString("matchSupervision.playersLoadError", bundle: .module, comment: "")
        }
    }

    enum OrganizerHome {
        static var roleBadge: String {
            NSLocalizedString("organizerHome.roleBadge", bundle: .module, comment: "")
        }
        static func greeting(_ name: String) -> String {
            String(format: NSLocalizedString("organizerHome.greeting", bundle: .module, comment: ""), name)
        }
        static var matchesTitle: String {
            NSLocalizedString("organizerHome.matchesTitle", bundle: .module, comment: "")
        }
    }

    enum AdminMatchDetail {
        static var currentLineup: String {
            NSLocalizedString("adminMatchDetail.currentLineup", bundle: .module, comment: "")
        }
        static var teamA: String {
            NSLocalizedString("adminMatchDetail.teamA", bundle: .module, comment: "")
        }
        static var teamB: String {
            NSLocalizedString("adminMatchDetail.teamB", bundle: .module, comment: "")
        }
        static var emptySlot: String {
            NSLocalizedString("adminMatchDetail.emptySlot", bundle: .module, comment: "")
        }
        static func spotsLeft(_ count: Int) -> String {
            String(format: NSLocalizedString("adminMatchDetail.spotsLeft", bundle: .module, comment: ""), count)
        }
        static var fieldDetails: String {
            NSLocalizedString("adminMatchDetail.fieldDetails", bundle: .module, comment: "")
        }
        static var shoeType: String {
            NSLocalizedString("adminMatchDetail.shoeType", bundle: .module, comment: "")
        }
        static var fieldType: String {
            NSLocalizedString("adminMatchDetail.fieldType", bundle: .module, comment: "")
        }
        static var parking: String {
            NSLocalizedString("adminMatchDetail.parking", bundle: .module, comment: "")
        }
        static var yes: String {
            NSLocalizedString("adminMatchDetail.yes", bundle: .module, comment: "")
        }
        static var no: String {
            NSLocalizedString("adminMatchDetail.no", bundle: .module, comment: "")
        }
        static var rules: String {
            NSLocalizedString("adminMatchDetail.rules", bundle: .module, comment: "")
        }
        static var extraInfo: String {
            NSLocalizedString("adminMatchDetail.extraInfo", bundle: .module, comment: "")
        }
        static var openInMapsTitle: String {
            NSLocalizedString("adminMatchDetail.openInMapsTitle", bundle: .module, comment: "")
        }
        static var openAppleMaps: String {
            NSLocalizedString("adminMatchDetail.openAppleMaps", bundle: .module, comment: "")
        }
        static var openGoogleMaps: String {
            NSLocalizedString("adminMatchDetail.openGoogleMaps", bundle: .module, comment: "")
        }
        static var playerCount: (_ current: Int, _ total: Int) -> String {
            { current, total in
                String(format: NSLocalizedString("adminMatchDetail.playerCount", bundle: .module, comment: ""), current, total)
            }
        }
        static var playersLoadError: String {
            NSLocalizedString("adminMatchDetail.playersLoadError", bundle: .module, comment: "")
        }
        static var rebalanceError: String {
            NSLocalizedString("adminMatchDetail.rebalanceError", bundle: .module, comment: "")
        }
    }

    enum MatchGender {
        static var mixed: String {
            NSLocalizedString("matchGender.mixed", bundle: .module, comment: "")
        }
        static var maleOnly: String {
            NSLocalizedString("matchGender.maleOnly", bundle: .module, comment: "")
        }
        static var femaleOnly: String {
            NSLocalizedString("matchGender.femaleOnly", bundle: .module, comment: "")
        }
    }

    enum MatchPlayerLevel {
        static var beginner: String {
            NSLocalizedString("matchPlayerLevel.beginner", bundle: .module, comment: "")
        }
        static var intermediate: String {
            NSLocalizedString("matchPlayerLevel.intermediate", bundle: .module, comment: "")
        }
        static var advanced: String {
            NSLocalizedString("matchPlayerLevel.advanced", bundle: .module, comment: "")
        }
        static var any: String {
            NSLocalizedString("matchPlayerLevel.any", bundle: .module, comment: "")
        }
    }

    enum AdminMatchStatus {
        static var scheduled: String {
            NSLocalizedString("adminMatchStatus.scheduled", bundle: .module, comment: "")
        }
        static var inProgress: String {
            NSLocalizedString("adminMatchStatus.inProgress", bundle: .module, comment: "")
        }
        static var completed: String {
            NSLocalizedString("adminMatchStatus.completed", bundle: .module, comment: "")
        }
        static var canceled: String {
            NSLocalizedString("adminMatchStatus.canceled", bundle: .module, comment: "")
        }
    }

    enum Validation {
        static func fieldNameMaxLength(_ length: Int) -> String {
            String(format: NSLocalizedString("validation.fieldNameMaxLength", bundle: .module, comment: ""), length)
        }
        static func addressOutOfCity(_ city: String) -> String {
            String(format: NSLocalizedString("validation.addressOutOfCity", bundle: .module, comment: ""), city)
        }
        static func minimumPrice(_ fieldCost: String, _ totalRevenue: String) -> String {
            String(format: NSLocalizedString("validation.minimumPrice", bundle: .module, comment: ""), fieldCost, totalRevenue)
        }
    }

    enum FieldImages {
        static var uploadError: String {
            NSLocalizedString("fieldImages.uploadError", bundle: .module, comment: "")
        }
        static var uploadSuccess: String {
            NSLocalizedString("fieldImages.uploadSuccess", bundle: .module, comment: "")
        }
        static var updateSuccess: String {
            NSLocalizedString("fieldImages.updateSuccess", bundle: .module, comment: "")
        }
        static var deleteSuccess: String {
            NSLocalizedString("fieldImages.deleteSuccess", bundle: .module, comment: "")
        }
    }

    enum AdminPanel {
        static var emptyOngoingMatches: String {
            NSLocalizedString("admin.emptyOngoingMatches", bundle: .module, comment: "")
        }
    }

    enum AdminLocations {
        static var emptyList: String {
            NSLocalizedString("admin.emptyLocations", bundle: .module, comment: "")
        }
    }
}
