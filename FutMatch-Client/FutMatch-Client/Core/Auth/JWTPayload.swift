import Foundation

/// Decodes the payload segment of a JWT without verifying its signature.
///
/// Signature verification is the backend's job — both `/auth/google/*` and
/// `/auth/apple/*` re-verify every token server-side against the issuer's JWKS.
/// This exists only for two client-side needs that don't require trust: reading
/// `aud` for a DEBUG audience-misconfiguration log, and reading `email`/`exp`
/// out of an Apple identity token when the SDK's credential object didn't carry
/// them (a repeat authorization omits `email` from the credential, though the
/// token payload still has it).
enum JWTPayload {
    static func decode(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }
}
