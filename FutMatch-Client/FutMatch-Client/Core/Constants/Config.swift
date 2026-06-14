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

    /// Whether Firebase App Check is installed.
    ///
    /// In DEBUG the debug provider must exchange a debug token with Firebase; until
    /// that token is registered in the console the exchange retries with backoff. The
    /// Remote Config fetch is bounded by a timeout so this no longer freezes launch,
    /// but other App-Check-gated calls (Auth, Firestore) may still be slow until the
    /// debug token is registered. Release builds always use App Attest / DeviceCheck.
    static var isAppCheckEnabled: Bool {
        return true
    }
}
