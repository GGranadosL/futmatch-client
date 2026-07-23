import Foundation
import Combine

final class AppGateViewModel: ObservableObject {

    @Published private(set) var state: AppGateState = .normal

    private let repository: AppGateRemoteConfigRepository
    private let defaults: UserDefaults

    private var currentVersionCode: Int {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return Int(build) ?? 0
    }

    init(repository: AppGateRemoteConfigRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    // MARK: - Public

    func evaluate() async {
        await repository.fetchAndActivate()
        let newState = resolvedState()
        await MainActor.run { state = newState }
    }

    func dismissSoftUpdate() {
        guard case .softUpdate = state else { return }
        recordSoftUpdateDismiss()
        Task { @MainActor in state = .normal }
    }

    // MARK: - State resolution

    private func resolvedState() -> AppGateState {
        let maintenance = repository.maintenanceConfig
        if maintenance.enabled {
            let copy = maintenance.copy.resolved()
            return .maintenance(
                title: copy?.title ?? "We are improving FutMatch",
                message: copy?.message ?? "The app is temporarily unavailable. Please try again in a moment."
            )
        }

        let update = repository.updateConfig
        let version = currentVersionCode

        if let min = update.minSupportedVersionCode, version < min {
            guard let storeUrl = update.storeUrl, !storeUrl.isEmpty else { return .normal }
            let copy = update.copy.resolved()
            return .mandatoryUpdate(
                title: copy?.title ?? "Version no longer supported",
                message: copy?.message ?? "This version of FutMatch is no longer supported. Please update to continue.",
                updateButtonLabel: copy?.updateButton ?? "Update",
                storeUrl: storeUrl
            )
        }

        if let rec = update.recommendedVersionCode, version < rec {
            guard let storeUrl = update.storeUrl, !storeUrl.isEmpty else { return .normal }
            guard shouldShowSoftUpdate(config: update, storeUrl: storeUrl) else { return .normal }
            let copy = update.copy.resolved()
            return .softUpdate(
                title: copy?.title ?? "New version available",
                message: copy?.message ?? "Update FutMatch to enjoy the latest improvements.",
                updateButtonLabel: copy?.updateButton ?? "Update",
                skipButtonLabel: copy?.skipButton ?? "Skip for now",
                storeUrl: storeUrl
            )
        }

        return .normal
    }

    // MARK: - Soft update frequency rules

    // Campaign key — matches Android identity: recommendedVersionCode + storeUrl
    private func campaignKey(recommendedVersionCode: Int, storeUrl: String) -> String {
        "appgate.softupdate.\(recommendedVersionCode).\(storeUrl)"
    }

    private func shouldShowSoftUpdate(config: AppUpdateConfig, storeUrl: String) -> Bool {
        guard let rec = config.recommendedVersionCode else { return false }
        let key = campaignKey(recommendedVersionCode: rec, storeUrl: storeUrl)
        let rules = config.softUpdateRules

        let showCount = defaults.integer(forKey: key + ".showCount")
        guard showCount < rules.maxShows else { return false }

        if rules.cooldownMinutes > 0, showCount > 0 {
            let lastDismissed = defaults.double(forKey: key + ".lastDismissed")
            if lastDismissed > 0 {
                let elapsed = Date().timeIntervalSince1970 - lastDismissed
                guard elapsed >= Double(rules.cooldownMinutes) * 60 else { return false }
            }
        }

        defaults.set(showCount + 1, forKey: key + ".showCount")
        return true
    }

    private func recordSoftUpdateDismiss() {
        let update = repository.updateConfig
        guard let rec = update.recommendedVersionCode, let storeUrl = update.storeUrl else { return }
        let key = campaignKey(recommendedVersionCode: rec, storeUrl: storeUrl)
        defaults.set(Date().timeIntervalSince1970, forKey: key + ".lastDismissed")
    }
}
