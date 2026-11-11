import Foundation

/// The public link for a match: `https://interfut.app/matches/{uuid}`.
/// Same contract as Android. The id only says which match to open; it grants nothing.
public struct MatchShareLink {
    static let host = "interfut.app"
    static let pathPrefix = "matches"

    /// Builds the link to share. Nil when the id isn't a UUID.
    public static func url(forMatchId matchId: String) -> URL? {
        guard UUID(uuidString: matchId) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(pathPrefix)/\(matchId)"
        return components.url
    }

    /// Reads the match id from an opened link. Accepts only
    /// `https://interfut.app/matches/{uuid}` (a trailing slash, query or fragment is ignored).
    public static func matchId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == host,
              components.port == nil,
              components.user == nil, components.password == nil else { return nil }
        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count == 2, segments[0] == pathPrefix,
              UUID(uuidString: String(segments[1])) != nil else { return nil }
        // Returned as written: links are built from the backend id, so it round-trips.
        return String(segments[1])
    }
}
