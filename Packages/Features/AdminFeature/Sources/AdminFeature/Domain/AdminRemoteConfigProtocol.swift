import Foundation

/// Abstracts Firebase Remote Config values consumed by AdminFeature.
/// The concrete implementation (`AdminRemoteConfigRepository`) lives in the
/// app target so AdminFeature stays Firebase-free.
public protocol AdminRemoteConfigProtocol {
    /// Maximum number of images that can be uploaded per field.
    /// Remote Config key: `admin_field_max_images`. Default: 1.
    var maxFieldImages: Int { get }

    /// Whether the admin panel button is shown in the home header.
    /// Remote Config key: `admin_feature_enabled`. Default: true.
    var isAdminFeatureEnabled: Bool { get }
}

// MARK: - Default implementation (UserDefaults-backed, set by the app target)

/// Reads values cached by `AdminRemoteConfigRepository` in UserDefaults.
/// Used as a drop-in when no custom implementation is injected.
public struct AdminRemoteConfig: AdminRemoteConfigProtocol {
    public static let maxImagesKey      = "fm_admin_field_max_images"
    public static let featureEnabledKey = "fm_admin_feature_enabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var maxFieldImages: Int {
        let stored = defaults.integer(forKey: Self.maxImagesKey)
        return stored > 0 ? stored : 1
    }

    public var isAdminFeatureEnabled: Bool {
        // `object(forKey:)` distinguishes "not set" (nil → default true) from false.
        (defaults.object(forKey: Self.featureEnabledKey) as? Bool) ?? true
    }
}
