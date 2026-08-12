import Foundation

// MARK: - DesktopEnrollmentTicket

/// The QR payload: a reference to a pending desktop enrollment, nothing more.
///
/// Both values are short-lived secrets. Keep them in view-model state only —
/// never write them to Keychain, UserDefaults, analytics, or logs.
struct DesktopEnrollmentTicket: Equatable {
    let enrollmentId: String
    let nonce: String

    init(enrollmentId: String, nonce: String) {
        self.enrollmentId = enrollmentId
        self.nonce = nonce
    }

    /// Decodes the compact JSON the desktop app renders. Returns `nil` for
    /// anything that isn't `{"enrollmentId": <uuid>, "nonce": <uuid>}` — a QR
    /// from some other app, a truncated scan, or a malformed payload.
    init?(qrPayload: String) {
        struct Payload: Decodable {
            let enrollmentId: String
            let nonce: String
        }

        let trimmed = qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = trimmed.data(using: .utf8),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            UUID(uuidString: payload.enrollmentId) != nil,
            UUID(uuidString: payload.nonce) != nil
        else { return nil }

        self.enrollmentId = payload.enrollmentId
        self.nonce = payload.nonce
    }
}

// MARK: - DesktopEnrollmentDetails

/// Server-reported inventory metadata for the desktop that generated the QR.
///
/// Every field is optional: enrollments created by an older desktop build carry
/// none of it. Show a localized "not available" instead of inventing a value.
/// This is troubleshooting data, not an attestation signal — the security
/// decision rests on the backend enrollment, the desktop's P-256 proof, the
/// admin JWT, and App Check.
struct DesktopEnrollmentDetails: Equatable {
    let deviceInfo: String?
    let appVersion: String?
    let osVersion: String?
}

// MARK: - DesktopEnrollment

/// A scanned ticket paired with the details the backend returned for it.
struct DesktopEnrollment: Equatable {
    let ticket: DesktopEnrollmentTicket
    let details: DesktopEnrollmentDetails
}

// MARK: - DesktopEnrollmentError

enum DesktopEnrollmentError: Error, Equatable {
    /// The scanned code isn't a Futmatch desktop enrollment QR.
    case invalidQR
}
