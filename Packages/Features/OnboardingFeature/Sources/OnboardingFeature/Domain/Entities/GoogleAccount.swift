import Foundation

/// A Google identity as returned by the Google Sign-In SDK.
///
/// `issuer` + `subject` form the durable identity the backend keys on
/// (`auth_identities` is unique over `(provider, issuer, provider_subject)`).
/// The email is *not* an identity key — it is carried only to show the user
/// which account they picked, and is never sent in the register request:
/// the backend reads it from the verified token itself.
///
/// The `idToken` is deliberately short-lived and must never be persisted.
/// Use `GoogleAuthProviding.refreshedIdToken()` to obtain a fresh one right
/// before calling the register endpoint.
public struct GoogleAccount: Equatable {
    public let idToken: String
    public let issuer: String
    public let subject: String
    public let email: String
    public let givenName: String
    public let familyName: String
    public let pictureURL: String?

    public init(
        idToken: String,
        issuer: String,
        subject: String,
        email: String,
        givenName: String,
        familyName: String,
        pictureURL: String? = nil
    ) {
        self.idToken = idToken
        self.issuer = issuer
        self.subject = subject
        self.email = email
        self.givenName = givenName
        self.familyName = familyName
        self.pictureURL = pictureURL
    }
}

/// The durable half of a `GoogleAccount` — everything needed to tell whether a
/// stored onboarding draft belongs to the account currently signing up, without
/// carrying the ID token around.
public struct GoogleDraftIdentity: Equatable {
    public let issuer: String
    public let subject: String

    public init(issuer: String, subject: String) {
        self.issuer = issuer
        self.subject = subject
    }
}

/// Lets the login screen drive a `fullScreenCover(item:)` straight off the
/// resolved account. `(issuer, sub)` is the identity the backend keys on, so
/// it is the right id here too — the email is not an identity key.
extension GoogleAccount: Identifiable {
    public var id: String { "\(issuer)|\(subject)" }
}

public extension GoogleAccount {
    var draftIdentity: GoogleDraftIdentity {
        GoogleDraftIdentity(issuer: issuer, subject: subject)
    }
}
