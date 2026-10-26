import Foundation
import SharedModels

extension AnalyticsErrorCode {
    /// Onboarding's own error enums have no backend code, so their case name is
    /// the stable code (`invalidCredentials` -> `INVALID_CREDENTIALS`). Anything
    /// else defers to the shared mapping. Messages are never included.
    static func forOnboarding(_ error: Error) -> String {
        switch error {
        case is AuthError, is SocialAuthError, is VerifyCodeError, is ForgotPasswordError:
            return snakeUpperCaseName(of: error)
        default:
            return from(error)
        }
    }

    private static func snakeUpperCaseName(of error: Error) -> String {
        let described = String(describing: error)
        let caseName = described.prefix { $0 != "(" }
        var result = ""
        for character in caseName {
            if character.isUppercase, !result.isEmpty { result.append("_") }
            result.append(contentsOf: character.uppercased())
        }
        return result.isEmpty ? unknown : result
    }
}
