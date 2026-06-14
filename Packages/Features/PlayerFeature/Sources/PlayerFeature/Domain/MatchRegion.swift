import Foundation

// MARK: - MatchRegion

/// Identifies the regional bucket used by the versioned matches feed
/// (`GET /match/matches/v2`) and its data-only push topic.
///
/// The backend defaults to `MX:CDMX` when no region is supplied. The app is
/// MX-only for now, so the region is a single hard-coded constant. Centralizing
/// it here keeps the query parameters, the local version key, and the FCM topic
/// in sync — change `default` (or inject another value) to support more regions.
public struct MatchRegion: Equatable, Sendable {
    public let countryCode: String
    public let stateCode: String

    public init(countryCode: String, stateCode: String) {
        self.countryCode = countryCode
        self.stateCode = stateCode
    }

    /// Default region used when the user has no explicit region selection.
    public static let `default` = MatchRegion(countryCode: "MX", stateCode: "CDMX")

    /// Canonical region key, e.g. `"MX:CDMX"`. Matches the `region` string the
    /// backend echoes back and is used as the local version-store key.
    public var key: String { "\(countryCode):\(stateCode)" }

    /// FCM topic for regional auto-refresh pushes, e.g. `"matches_MX_CDMX"`.
    public var topic: String { "matches_\(countryCode)_\(stateCode)" }
}
