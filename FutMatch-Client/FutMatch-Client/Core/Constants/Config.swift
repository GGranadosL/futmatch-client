//
//  Config.swift
//  FutMatch-Client
//
//  Created by Gerardo Granados Lopez on 13/01/26.
//

import Foundation

// MARK: - Environment

/// API environment — change this single line to switch between QA and Production.
enum AppEnvironment {
    case qa
    case production
    
    var baseURL: String {
        switch self {
        case .qa:
            return "https://futmatch-e2tu.onrender.com"
        case .production:
            return "https://futmatch-iy5u.onrender.com" // TODO: Replace with production URL
        }
    }

    /// The backend's `GOOGLE_OAUTH_WEB_CLIENT_ID` for this environment — the same
    /// web client id Android passes to Credential Manager.
    ///
    /// Passed to the SDK as `serverClientID`, which asks Google to mint the ID
    /// token for that audience so `/auth/google/*` can validate it. It is an
    /// audience, not a secret.
    ///
    /// Both environments point at the same Google Cloud project (669918628196),
    /// so the audience is identical. Split these if QA ever gets its own project.
    var googleServerClientID: String {
        switch self {
        case .qa, .production:
            return "669918628196-l3bkpcn2tstdpajgl9t5boo3od39ar5p.apps.googleusercontent.com"
        }
    }

    /// This app's own OAuth 2.0 **iOS** client id, from the Google Cloud project
    /// (APIs & Services ▸ Credentials ▸ Create credentials ▸ OAuth client ID ▸
    /// iOS), created against the app's bundle id.
    ///
    /// Leave empty to fall back to `CLIENT_ID` in GoogleService-Info.plist, which
    /// is where the Firebase console writes this same value if the Google provider
    /// is enabled there instead. Either route works — only one is needed.
    var googleIOSClientID: String {
        switch self {
        case .qa, .production:
            return "669918628196-fd4b7m4emtp91afd86k71kduofoph24i.apps.googleusercontent.com"
        }
    }
}

// MARK: - Config

/// Centralized app configuration constants
enum Config {
    /// 👇 Change this to switch environment
    static let environment: AppEnvironment = .qa
    
    /// API base URL derived from current environment
    static var apiBaseURL: String { environment.baseURL }
    
    static let appVersion = "1.0.0"
    static let appName = "FutMatch"

    /// Whether Firebase App Check is installed. Always on.
    ///
    /// DEBUG builds attest with the debug provider and the token pinned in
    /// `AppDelegate`; that UUID must stay registered in the Firebase console or the
    /// exchange retries with backoff and App-Check-gated calls (Auth, Firestore) get
    /// slow. Release builds use App Attest / DeviceCheck.
    static var isAppCheckEnabled: Bool {
        return true
    }

    /// Web OAuth client id the backend validates Google ID tokens against.
    static var googleServerClientID: String { environment.googleServerClientID }

    /// This app's iOS OAuth client id. Empty falls back to GoogleService-Info.plist.
    static var googleIOSClientID: String { environment.googleIOSClientID }
}
