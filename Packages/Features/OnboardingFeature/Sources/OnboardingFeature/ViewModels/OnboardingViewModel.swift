import Foundation
import SwiftUI
import UIKit
import Combine
import NetworkFramework
import SharedModels

/// ViewModel for the entire Onboarding flow
@MainActor
public class OnboardingViewModel: ObservableObject {
    // MARK: - Navigation
    @Published public var currentStep: Int = 1

    // MARK: - Step 1: Personal Info
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    /// `nil` until the user actually picks a date — no default is pre-selected, so the field
    /// can't be silently left at a value the user never chose.
    @Published public var birthDate: Date? = nil
    @Published public var gender: GenderOption? = nil

    /// Dates the birth-date picker may offer. Capping the upper bound at the minimum age
    /// makes an under-age selection impossible, so the user never fills the form only to
    /// find the "Next step" button disabled.
    public var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let upper = calendar.date(byAdding: .year, value: -FieldValidator.minimumAge, to: now) ?? now
        let lower = calendar.date(byAdding: .year, value: -120, to: now) ?? upper
        return lower...upper
    }

    // MARK: - Step 2: Contact & Account
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var countryCode: String = ""
    /// ISO-2 of the selected dial-code entry (e.g. "MX"). Stored so the picker
    /// can disambiguate countries that share the same dial code (e.g. US/CA/DO → "+1").
    @Published public var selectedDialCodeISO: String = ""
    @Published public var phone: String = ""
    @Published public var country: String = ""
    /// ISO-2 country code (e.g., "US", "MX"). Sent to the API in the register request.
    @Published public var countryISO: String = ""
    /// Country list loaded from Remote Config (via FetchCountriesUseCase).
    @Published public var countries: [Country] = []
    /// Dial-code list loaded from Remote Config (via FetchDialCodesUseCase).
    @Published public var dialCodes: [DialCode] = []

    // MARK: - Step 3: Football Profile
    @Published public var profilePicURL: String = ""
    @Published public var profileImage: Image? = nil
    /// Raw JPEG data of the selected photo. Converted to base64 and sent in registerStart.
    @Published public var profileImageData: Data? = nil
    @Published public var playerPosition: PositionOption? = nil
    @Published public var level: LevelOption = .intermediate
    /// `true` while `useProviderPhoto()` is downloading. Drives the loading state on
    /// the "Usar foto de Google" pill and disables both photo-source pills so a
    /// second tap can't race the fetch in flight.
    @Published public var isLoadingProviderPhoto: Bool = false

    // MARK: - UI State
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var showVerification: Bool = false
    @Published public var isVerificationComplete: Bool = false
    @Published public var resendCodeTimeInSeconds: Int = 60
    @Published public var isDraftRestored: Bool = false
    /// Set when the social credential expired mid-onboarding (Apple only — its
    /// identity token is short-lived and cannot be re-minted silently). The
    /// container watches this to bounce back to login, draft already saved, so a
    /// second tap on the provider button resumes exactly where this left off.
    @Published public private(set) var requiresReauthentication = false

    // MARK: - Social Auth
    /// Non-nil when this onboarding was started from "Continue with Google" or
    /// "Continue with Apple". Drives every branch below: no password, a locked
    /// email, and a register call that skips the email verification step entirely.
    public let socialAccount: SocialAccount?

    public var isSocialFlow: Bool { socialAccount != nil }
    public var provider: AuthProvider? { socialAccount?.provider }

    /// Whether the backend should import the provider's avatar or leave the
    /// account without one. `nil` for Apple, which never supplies one — the
    /// register request simply omits the field. Picking a photo in step 3 fills
    /// `profileImageData`, and that image is uploaded separately after
    /// registration, so importing the provider's on top of it would just
    /// overwrite the user's choice.
    var profilePictureSource: ProfilePictureSource? {
        guard provider == .google else { return nil }
        return profileImageData == nil ? .providerImported : .custom
    }

    /// Whether the signed-in provider actually gave us a photo to offer as a
    /// pill in Step 3. Google does; Apple never does — this, not `isSocialFlow`,
    /// is what the Step 3 UI keys off, so an Apple sign-up falls through to the
    /// plain upload caption instead of showing a broken "use provider photo" pill.
    public var hasProviderPhoto: Bool { socialAccount?.pictureURL != nil }

    // MARK: - Use Cases
    private let registerUserUseCase: RegisterUserUseCaseProtocol
    private let verifyCodeUseCase: VerifyCodeUseCaseProtocol
    private let registerSocialUserUseCase: RegisterSocialUserUseCaseProtocol?
    private let saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol?
    private let getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol?
    private let clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol?
    private let fetchCountriesUseCase: FetchCountriesUseCaseProtocol
    private let fetchDialCodesUseCase: FetchDialCodesUseCaseProtocol

    // MARK: - Auto-save
    private var saveDraftTask: Task<Void, Never>?
    /// Watches the social credential's expiry (Apple only) and bounces to login
    /// as soon as it lapses, rather than waiting for the user to hit submit with a
    /// dead token.
    private var expiryTask: Task<Void, Never>?

    // MARK: - Initialization
    public init(
        registerUserUseCase: RegisterUserUseCaseProtocol? = nil,
        verifyCodeUseCase: VerifyCodeUseCaseProtocol? = nil,
        registerSocialUserUseCase: RegisterSocialUserUseCaseProtocol? = nil,
        socialAccount: SocialAccount? = nil,
        saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol? = nil,
        getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol? = nil,
        clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol? = nil,
        fetchCountriesUseCase: FetchCountriesUseCaseProtocol? = nil,
        fetchDialCodesUseCase: FetchDialCodesUseCaseProtocol? = nil
    ) {
        let authService = AuthService()
        self.registerUserUseCase = registerUserUseCase ?? RegisterUserUseCase(authService: authService)
        self.verifyCodeUseCase = verifyCodeUseCase ?? VerifyCodeUseCase(authService: authService)
        self.registerSocialUserUseCase = registerSocialUserUseCase
        self.socialAccount = socialAccount
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        self.fetchCountriesUseCase = fetchCountriesUseCase ?? FetchCountriesUseCase(repository: FallbackCountryRepository())
        self.fetchDialCodesUseCase = fetchDialCodesUseCase ?? FetchDialCodesUseCase(repository: FallbackDialCodeRepository())

        // The provider's values go in first so a matching draft can still override
        // them with whatever the user actually typed before they walked away.
        applySocialPrefill()
        scheduleCredentialExpiry()

        Task {
            await loadDraft()
            await loadCountries()
            await loadDialCodes()
            await useProviderPhoto()
        }
    }

    // MARK: - Countries

    func loadCountries() async {
        let result = await fetchCountriesUseCase.execute()
        countries = result
    }

    func loadDialCodes() async {
        let result = await fetchDialCodesUseCase.execute()
        dialCodes = result
    }

    // MARK: - Social Prefill

    /// Copies across everything the provider actually gives us. Google's basic
    /// scopes carry name, email and picture; Apple carries name and email only on
    /// the very first authorization (never a picture, and nothing at all on a
    /// repeat authorization) — birth date, gender and phone are never available
    /// from either, so those steps still have to be filled in by hand.
    private func applySocialPrefill() {
        guard let account = socialAccount else { return }
        firstName = Self.sanitizedName(account.givenName)
        lastName = Self.sanitizedName(account.familyName)
        email = account.email
        profilePicURL = account.pictureURL ?? ""
    }

    /// Trims a provider display name down to what `FieldValidator.validateName`
    /// accepts (letters and spaces, 30 max).
    ///
    /// Social names routinely contain hyphens and apostrophes — "Jean-Luc",
    /// "O'Brien". Prefilling those verbatim leaves step 1 blocked with every field
    /// visibly populated and no error the user can act on, so they get cleaned here
    /// rather than by loosening validation for everyone.
    static func sanitizedName(_ raw: String) -> String {
        let allowed = raw.filter { $0.isLetter || $0.isWhitespace }
        let collapsed = allowed.split(separator: " ").joined(separator: " ")
        return String(collapsed.prefix(30))
    }

    /// Switches the avatar back to the provider's photo — the counterpart of
    /// picking a custom one in Step 3. A no-op when the provider has none
    /// (`hasProviderPhoto == false`, i.e. always for Apple).
    ///
    /// Clears `profileImageData` first: that property is what `profilePictureSource`
    /// reads to decide `.providerImported` vs `.custom`, so this is what "undoes" a
    /// previously picked custom photo, even before the download below finishes.
    ///
    /// Deliberately does not touch `profileImageData` afterwards, and never did:
    /// that property means "the user picked their own photo, upload it after
    /// registering". The provider's picture is imported server-side from the
    /// verified token instead, so writing it here would both re-upload it and flip
    /// `profilePictureSource` back to `.custom`.
    ///
    /// Called once at init to show the provider's photo up front, and again from
    /// the "Usar foto de Google" pill in Step 3 — which also doubles as the retry
    /// path if the initial silent download failed (e.g. no network yet at launch).
    public func useProviderPhoto() async {
        profileImageData = nil

        guard let urlString = socialAccount?.pictureURL,
              let url = URL(string: urlString) else { return }

        isLoadingProviderPhoto = true
        defer { isLoadingProviderPhoto = false }

        // A failed fetch leaves whatever was on screen before rather than blanking
        // the avatar — the user can just tap the pill again once they have signal.
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }

        profileImage = Image(uiImage: image)
    }

    // MARK: - Credential Expiry (Apple)

    /// Schedules the bounce-to-login for the moment the social credential expires,
    /// rather than waiting for the user to hit submit with a dead token. Google's
    /// credential has no `expiresAt` (its SDK can mint a fresh one silently), so
    /// this is a no-op outside an Apple flow.
    private func scheduleCredentialExpiry() {
        expiryTask?.cancel()
        guard let expiresAt = socialAccount?.credential.expiresAt else { return }
        expiryTask = Task { [weak self] in
            let seconds = expiresAt.timeIntervalSinceNow
            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.bounceToLoginForReauthentication()
        }
    }

    /// Re-checked whenever the app returns to the foreground: `Task.sleep` isn't
    /// reliable across suspension, and a relaunch has no in-memory task to have
    /// scheduled from at all.
    public func checkCredentialExpiry() {
        guard let credential = socialAccount?.credential, credential.isExpired else { return }
        Task { await bounceToLoginForReauthentication() }
    }

    private func bounceToLoginForReauthentication() async {
        guard !isLoading, !isVerificationComplete, !requiresReauthentication else { return }
        await saveDraftIfNeeded()
        requiresReauthentication = true
    }

    // MARK: - Navigation
    public func nextStep() {
        guard currentStep < 4 else { return }
        withAnimation {
            currentStep += 1
        }
    }

    public func previousStep() {
        guard currentStep > 1 else { return }
        withAnimation {
            currentStep -= 1
        }
    }

    public func goToStep(_ step: Int) {
        guard step >= 1, step <= 4, step != currentStep else { return }
        withAnimation {
            currentStep = step
        }
    }

    // MARK: - Validations

    // Step 1 Validations
    public var isStep1Valid: Bool {
        isFirstNameValid && isLastNameValid && isBirthDateValid && gender != nil
    }

    public var isFirstNameValid: Bool {
        let name = firstName.trimmingCharacters(in: .whitespaces)
        return FieldValidator.validateName(name).isValid
    }

    public var isLastNameValid: Bool {
        let name = lastName.trimmingCharacters(in: .whitespaces)
        return FieldValidator.validateName(name).isValid
    }

    public var isBirthDateValid: Bool {
        guard let birthDate else { return false }
        return FieldValidator.validateBirthDate(birthDate).isValid
    }

    // Step 2 Validations
    public var isStep2Valid: Bool {
        // Social accounts are stored with `password = null` — there is no field to
        // fill and nothing to validate. And a social email can legitimately be
        // empty (Apple on a repeat authorization) — blocking on it here would trap
        // the user on this step forever instead of letting `register` surface the
        // backend's actual, actionable error.
        return (isSocialFlow || isEmailValid)
            && (isSocialFlow || isPasswordValid)
            && isPhoneValid
            && !countryCode.isEmpty
            && !countryISO.isEmpty
    }

    public var isEmailValid: Bool {
        return FieldValidator.validateEmail(email).isValid
    }

    public var isPasswordValid: Bool {
        return FieldValidator.validatePassword(password).isValid
    }

    public var passwordValidationErrors: [String] {
        return FieldValidator.getPasswordErrors(password)
    }

    public var isPhoneValid: Bool {
        // Phone must match backend regex: ^\+?[1-9]\d{1,14}$
        return FieldValidator.validatePhone(cleanedPhone).isValid
    }

    /// Phone number cleaned for API submission
    public var cleanedPhone: String {
        countryCode + phone.filter { $0.isNumber }
    }

    // Step 3 Validations
    public var isStep3Valid: Bool {
        // The user must explicitly pick a playing position. Level is set in a
        // separate flow (defaulting to .intermediate) and profilePic is optional.
        playerPosition != nil
    }

    // MARK: - Actions
    public func submitRegistration() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSocialFlow {
                try await submitSocialRegistration()
            } else {
                let request = buildRegisterRequest()
                let result = try await registerUserUseCase.execute(request: request)

                if result.success {
                    resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
                    showVerification = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Registers a social account and lands the user straight on the success screen.
    ///
    /// There is no verification code to enter: the provider already handed us a
    /// verified email, so `/auth/{provider}/register` creates the account and
    /// returns a session in one call. Setting `isVerificationComplete` is what the
    /// container watches to show `RegistrationSuccessView`, so the code screen is
    /// bypassed entirely.
    private func submitSocialRegistration() async throws {
        guard let registerSocialUserUseCase, let socialAccount else {
            throw AuthError.missingSocialSession
        }

        try await registerSocialUserUseCase.execute(buildSocialRegistrationInput(account: socialAccount))
        expiryTask?.cancel()
        await clearDraftAfterSuccess()
        isVerificationComplete = true
    }

    // MARK: - Verification
    public func verifyCode(_ code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
            let result = try await verifyCodeUseCase.execute(email: cleanEmail, code: code)

            if result.success {
                // Clear draft after successful registration
                await clearDraftAfterSuccess()

                // Navigate to Home
                isVerificationComplete = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func resendVerificationCode() async {
        isLoading = true
        errorMessage = nil

        do {
            let request = buildRegisterRequest()
            let result = try await registerUserUseCase.execute(request: request)

            if result.success {
                resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func buildRegisterRequest() -> RegisterStartRequest {
        // `birthDate` is guaranteed non-nil by the time this runs: the UI disables
        // "Next step" on Step 1 (`isStep1Valid`) until the user picks one, and
        // submission only happens after all 4 steps are complete.
        let birthDateTimestamp = Int64((birthDate ?? Date()).timeIntervalSince1970 * 1000)

        // Profile picture is uploaded separately after email verification via /user/profile-pic endpoint,
        // not during initial registration.
        return RegisterStartRequest(
            name: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            phone: cleanedPhone,
            country: countryISO,
            birthDate: birthDateTimestamp,
            gender: gender?.toGender() ?? .male,
            playerPosition: playerPosition?.toPlayerPosition() ?? .midfielder,
            profilePic: nil,
            level: level.toPlayerLevel(),
            userRole: .player
        )
    }

    /// The social counterpart of `buildRegisterRequest`.
    ///
    /// No email and no password: the backend takes the email from the verified
    /// token. The phone keeps the same `cleanedPhone` shape the password sign-up
    /// sends — both land in the same `users.phone` column.
    private func buildSocialRegistrationInput(account: SocialAccount) -> SocialRegistrationInput {
        SocialRegistrationInput(
            identity: account.draftIdentity,
            credential: account.credential,
            name: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phone: cleanedPhone,
            country: countryISO,
            birthDate: Int64((birthDate ?? Date()).timeIntervalSince1970 * 1000),
            gender: gender?.toGender() ?? .male,
            playerPosition: playerPosition?.toPlayerPosition() ?? .midfielder,
            level: level.toPlayerLevel(),
            profilePictureSource: profilePictureSource
        )
    }
}

// MARK: - Options Enums
public enum GenderOption: String, CaseIterable, CustomStringConvertible {
    case male
    case female
    case other

    public var description: String {
        switch self {
        case .male: return L10n.Gender.male
        case .female: return L10n.Gender.female
        case .other: return L10n.Gender.other
        }
    }

    func toGender() -> Gender {
        switch self {
        case .male: return .male
        case .female: return .female
        case .other: return .other
        }
    }
}

public enum PositionOption: String, CaseIterable, CustomStringConvertible {
    case goalkeeper
    case defender
    case midfielder
    case forward

    public var description: String {
        switch self {
        case .goalkeeper: return L10n.Position.goalkeeper
        case .defender: return L10n.Position.defender
        case .midfielder: return L10n.Position.midfielder
        case .forward: return L10n.Position.forward
        }
    }

    func toPlayerPosition() -> PlayerPosition {
        switch self {
        case .goalkeeper: return .goalkeeper
        case .defender: return .defender
        case .midfielder: return .midfielder
        case .forward: return .forward
        }
    }
}

// MARK: - Onboarding Draft Persistence

extension OnboardingViewModel {
    /// Schedule auto-save with debounce (500ms delay)
    public func scheduleSaveDraft() {
        guard saveOnboardingDraftUseCase != nil else { return }

        saveDraftTask?.cancel()
        saveDraftTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await saveDraft()
        }
    }

    /// Save draft immediately when needed (e.g., onDisappear)
    public func saveDraftIfNeeded() async {
        saveDraftTask?.cancel()
        await saveDraft()
    }

    /// Save current onboarding data as draft
    private func saveDraft() async {
        guard let useCase = saveOnboardingDraftUseCase else { return }

        let draft = OnboardingDraft(
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: gender?.rawValue,
            email: email,
            phoneCountryCode: countryCode,
            phone: phone,
            country: country,
            countryISO: countryISO,
            currentStep: currentStep,
            provider: socialAccount?.provider,
            socialIssuer: socialAccount?.issuer,
            socialSubject: socialAccount?.subject,
            socialPictureURL: socialAccount?.pictureURL
        )

        // The social credential is never written anywhere — both backends forbid
        // persisting it. A resumed sign-up mints a fresh one through
        // `refreshedCredential(matching:)` (Google, silently) or a fresh sign-in
        // (Apple, via the reauthentication bounce).
        try? await useCase.execute(draft, password: password.isEmpty ? nil : password)
    }

    /// Load saved draft on initialization
    private func loadDraft() async {
        guard let useCase = getOnboardingDraftUseCase else { return }

        // The use case only hands back a draft belonging to this flow: the social
        // identity that's signing up, or a password draft when there is none.
        if let result = try? await useCase.execute(socialIdentity: socialAccount?.draftIdentity) {
            await restoreDraft(result.draft, password: result.password)
        }
    }

    /// Restore draft data to view model
    private func restoreDraft(_ draft: OnboardingDraft, password: String?) async {
        firstName = draft.firstName
        lastName = draft.lastName
        if let draftedBirthDate = draft.birthDate {
            // A draft saved before the user's last birthday can fall outside the picker range.
            let range = birthDateRange
            birthDate = min(max(draftedBirthDate, range.lowerBound), range.upperBound)
        }
        if let genderValue = draft.gender, let gender = GenderOption(rawValue: genderValue) {
            self.gender = gender
        }
        email = draft.email
        countryCode = draft.phoneCountryCode
        phone = draft.phone
        country = draft.country
        countryISO = draft.countryISO
        currentStep = draft.currentStep
        self.password = password ?? ""
        isDraftRestored = true
    }

    /// Clear draft after successful registration
    public func clearDraftAfterSuccess() async {
        guard let useCase = clearOnboardingDraftUseCase else { return }

        try? await useCase.execute()
    }

    /// Upload profile picture to /user/profile-pic after email verification.
    /// Called after MFA validation but before navigating to home.
    public func uploadProfilePictureIfNeeded() async {
        guard let imageData = profileImageData, !imageData.isEmpty else { return }

        do {
            struct UploadResponse: Decodable { let data: String }
            let _: UploadResponse = try await APIClient.shared.upload(
                endpoint: OnboardingUploadEndpoint.profilePic,
                fileData: imageData,
                fileName: "perfil.jpg",
                mimeType: "image/jpeg"
            )
        } catch {
            // Non-blocking — user can update picture later from profile
        }
    }
}
// MARK: - Upload Endpoint

enum OnboardingUploadEndpoint: APIEndpoint {
    case profilePic

    var path: String { "/user/profile-pic" }
    var method: HTTPMethod { .post }
}

public enum LevelOption: String, CaseIterable, CustomStringConvertible {
    case beginner = "Principiante"
    case amateur = "Amateur"
    case intermediate = "Inter0"
    case advanced = "Avanzado"
    case professional = "Profesional"

    public var description: String { rawValue }

    func toPlayerLevel() -> PlayerLevel {
        switch self {
        case .beginner: return .beginner
        case .amateur: return .amateur
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        case .professional: return .professional
        }
    }
}
