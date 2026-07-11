import Foundation

// MARK: - Domain Models

struct AppMaintenanceConfig {
    let enabled: Bool
    let copy: [String: AppGateCopy]

    static let safe = AppMaintenanceConfig(enabled: false, copy: [:])
}

struct AppUpdateConfig {
    let minSupportedVersionCode: Int?
    let recommendedVersionCode: Int?
    let storeUrl: String?
    let softUpdateRules: SoftUpdateRules
    let copy: [String: AppUpdateCopy]

    static let safe = AppUpdateConfig(
        minSupportedVersionCode: nil,
        recommendedVersionCode: nil,
        storeUrl: nil,
        softUpdateRules: .default,
        copy: [:]
    )
}

struct SoftUpdateRules {
    let maxShows: Int
    let cooldownMinutes: Int

    static let `default` = SoftUpdateRules(maxShows: 1, cooldownMinutes: 0)
}

struct AppGateCopy {
    let title: String
    let message: String
}

struct AppUpdateCopy {
    let title: String
    let message: String
    let updateButton: String
    let skipButton: String?
}

// MARK: - Evaluated State

enum AppGateState: Equatable {
    case normal
    case maintenance(title: String, message: String)
    case mandatoryUpdate(title: String, message: String, updateButtonLabel: String, storeUrl: String)
    case softUpdate(title: String, message: String, updateButtonLabel: String, skipButtonLabel: String, storeUrl: String)
}

// MARK: - Parsing

extension AppMaintenanceConfig {
    init?(json: [String: Any]) {
        guard let enabled = json["enabled"] as? Bool else { return nil }
        var copy: [String: AppGateCopy] = [:]
        if let copyDict = json["copy"] as? [String: [String: String]] {
            for (locale, texts) in copyDict {
                guard let title = texts["title"], let message = texts["message"] else { continue }
                copy[locale] = AppGateCopy(title: title, message: message)
            }
        }
        self.enabled = enabled
        self.copy = copy
    }
}

extension AppUpdateConfig {
    init?(json: [String: Any]) {
        let minVersion = json["minSupportedVersionCode"] as? Int
        let recVersion = json["recommendedVersionCode"] as? Int
        let storeUrl = json["storeUrl"] as? String

        var rules = SoftUpdateRules.default
        if let rulesDict = json["softUpdateRules"] as? [String: Any] {
            let maxShows = rulesDict["maxShows"] as? Int ?? 1
            let cooldown = rulesDict["cooldownMinutes"] as? Int ?? 0
            rules = SoftUpdateRules(maxShows: maxShows, cooldownMinutes: cooldown)
        }

        var copy: [String: AppUpdateCopy] = [:]
        if let copyDict = json["copy"] as? [String: [String: String]] {
            for (locale, texts) in copyDict {
                guard let title = texts["title"], let message = texts["message"] else { continue }
                copy[locale] = AppUpdateCopy(
                    title: title,
                    message: message,
                    updateButton: texts["updateButton"] ?? "Update",
                    skipButton: texts["skipButton"]
                )
            }
        }

        self.minSupportedVersionCode = minVersion
        self.recommendedVersionCode = recVersion
        self.storeUrl = storeUrl
        self.softUpdateRules = rules
        self.copy = copy
    }
}

// MARK: - Locale resolution

extension [String: AppGateCopy] {
    func resolved(for locale: Locale = .current) -> AppGateCopy? {
        let tag = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let exact = self[tag] { return exact }
        let base = String(tag.prefix(2))
        if let lang = self[base] { return lang }
        return self["en"]
    }
}

extension [String: AppUpdateCopy] {
    func resolved(for locale: Locale = .current) -> AppUpdateCopy? {
        let tag = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let exact = self[tag] { return exact }
        let base = String(tag.prefix(2))
        if let lang = self[base] { return lang }
        return self["en"]
    }
}
