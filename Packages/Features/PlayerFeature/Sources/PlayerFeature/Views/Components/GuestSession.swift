import SwiftUI

// MARK: - Guest session environment
//
// Without an account the app runs in guest mode: only the matches list and match
// detail are open (App Store guideline 5.1.1(v)). Everything account based asks
// the user to sign in through a dismissible sheet presented by the app target.
// These values let any screen check the mode and ask for sign-in without
// threading closures through every initializer.

/// Opens the sign-in sheet. Set by the app root; a no-op by default (previews, tests).
public struct RequestSignInAction {
    private let handler: () -> Void

    public init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    public func callAsFunction() {
        handler()
    }
}

private struct RequestSignInKey: EnvironmentKey {
    static let defaultValue = RequestSignInAction {}
}

private struct IsAuthenticatedKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    /// Opens the sign-in sheet over the current screen.
    var requestSignIn: RequestSignInAction {
        get { self[RequestSignInKey.self] }
        set { self[RequestSignInKey.self] = newValue }
    }

    /// `false` while browsing as a guest.
    var isAuthenticated: Bool {
        get { self[IsAuthenticatedKey.self] }
        set { self[IsAuthenticatedKey.self] = newValue }
    }
}
