import Foundation

/// A no-content response.
///
/// Use as the generic `T` for `APIClient.request` when the endpoint returns no
/// meaningful body — e.g. `DELETE` (often `204 No Content`) or write endpoints
/// whose response payload the caller ignores. It decodes successfully from an
/// empty body, a `null`, or any JSON shape, so a 2xx status alone counts as
/// success and a differently-shaped body never triggers a decoding failure.
public struct EmptyResponse: Decodable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}
