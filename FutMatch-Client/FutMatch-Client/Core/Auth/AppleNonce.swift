import Foundation
import CryptoKit

/// Apple's identity token has no built-in replay defence the way Google's SDK
/// provides, so the login flow generates a nonce, sends its SHA-256 hash to Apple
/// (which embeds it in the signed token), and later hands the *raw* nonce to the
/// backend so it can recompute the hash and confirm the token was minted for this
/// exact request.
enum AppleNonce {
    /// A fresh random nonce, base64url-encoded (`ASAuthorizationAppleIDRequest.nonce`
    /// accepts any string; base64url keeps it URL/JSON-safe without escaping).
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate secure random nonce")
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// SHA-256 of the raw nonce, hex-encoded — what gets passed to
    /// `ASAuthorizationAppleIDRequest.nonce` and what the backend expects the
    /// token's `nonce` claim to equal.
    static func sha256Hex(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
