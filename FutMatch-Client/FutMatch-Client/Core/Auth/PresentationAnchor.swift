import UIKit

/// Finds the view controller (Google) or window (Apple) that a social sign-in
/// sheet should present from. Shared because both `GoogleSignInService` and
/// `AppleSignInService` need the same foreground-active scene lookup.
enum PresentationAnchor {
    static func topViewController() -> UIViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        var controller = root
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }
}
