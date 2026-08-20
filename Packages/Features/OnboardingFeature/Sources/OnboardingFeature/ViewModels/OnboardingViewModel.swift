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
    /// `true` while `useGooglePhoto()` is downloading. Drives the loading state on
    /// the "Usar foto de Google" pill and disables both photo-source pills so a
    /// second tap can't race the fetch in flight.
    @Published public var isLoadingGooglePhoto: Bool = false
    
    // MARK: - UI State
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var showVerification: Bool = false
    @Published public var isVerificationComplete: Bool = false
    @Published public var resendCodeTimeInSeconds: Int = 60
    @Published public var isDraftRestored: Bool = false

    // MARK: - Google
    /// Non-nil when this onboarding was started from "Continue with Google".
    /// Drives every branch below: no password, a locked email, and a register
    /// call that skips the email verification step entirely.
    public let googleAccount: GoogleAccount?

    public var isGoogleFlow: Bool { googleAccount != nil }

    /// Whether the backend should import Google's avatar or leave the account
    /// without one. Picking a photo in step 3 fills `profileImageData`, and that
    /// image is uploaded separately after registration — importing Google's on
    /// top of it would just overwrite the user's choice.
    var profilePictureSource: ProfilePictureSource {
        profileImageData == nil ? .google : .custom
    }

    // MARK: - Use Cases
    private let registerUserUseCase: RegisterUserUseCaseProtocol
    private let verifyCodeUseCase: VerifyCodeUseCaseProtocol
    private let registerGoogleUserUseCase: RegisterGoogleUserUseCaseProtocol?
    private let saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol?
    private let getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol?
    private let clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol?
    private let fetchCountriesUseCase: FetchCountriesUseCaseProtocol
    private let fetchDialCodesUseCase: FetchDialCodesUseCaseProtocol
    
    // MARK: - Auto-save
    private var saveDraftTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(
        registerUserUseCase: RegisterUserUseCaseProtocol? = nil,
        verifyCodeUseCase: VerifyCodeUseCaseProtocol? = nil,
        registerGoogleUserUseCase: RegisterGoogleUserUseCaseProtocol? = nil,
        googleAccount: GoogleAccount? = nil,
        saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol? = nil,
        getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol? = nil,
        clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol? = nil,
        fetchCountriesUseCase: FetchCountriesUseCaseProtocol? = nil,
        fetchDialCodesUseCase: FetchDialCodesUseCaseProtocol? = nil
    ) {
        let authService = AuthService()
        self.registerUserUseCase = registerUserUseCase ?? RegisterUserUseCase(authService: authService)
        self.verifyCodeUseCase = verifyCodeUseCase ?? VerifyCodeUseCase(authService: authService)
        self.registerGoogleUserUseCase = registerGoogleUserUseCase
        self.googleAccount = googleAccount
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        self.fetchCountriesUseCase = fetchCountriesUseCase ?? FetchCountriesUseCase(repository: FallbackCountryRepository())
        self.fetchDialCodesUseCase = fetchDialCodesUseCase ?? FetchDialCodesUseCase(repository: FallbackDialCodeRepository())

        // Google's values go in first so a matching draft can still override them
        // with whatever the user actually typed before they walked away.
        applyGooglePrefill()

        Task {
            await loadDraft()
            await loadCountries()
            await loadDialCodes()
            await useGooglePhoto()
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

    // MARK: - Google Prefill

    /// Copies across everything Google actually gives us. Basic scopes carry only
    /// name, email and picture — birth date, gender and phone are not available,
    /// so those steps still have to be filled in by hand.
    private func applyGooglePrefill() {
        guard let account = googleAccount else { return }
        firstName = Self.sanitizedName(account.givenName)
        lastName = Self.sanitizedName(account.familyName)
        email = account.email
        profilePicURL = account.pictureURL ?? ""
    }

    /// Trims a Google display name down to what `FieldValidator.validateName`
    /// accepts (letters and spaces, 30 max).
    ///
    /// Google names routinely contain hyphens and apostrophes — "Jean-Luc",
    /// "O'Brien". Prefilling those verbatim leaves step 1 blocked with every field
    /// visibly populated and no error the user can act on, so they get cleaned here
    /// rather than by loosening validation for everyone.
    static func sanitizedName(_ raw: String) -> String {
        let allowed = raw.filter { $0.isLetter || $0.isWhitespace }
        let collapsed = allowed.split(separator: " ").joined(separator: " ")
        return String(collapsed.prefix(30))
    }

    /// Switches the avatar back to Google's photo — the counterpart of picking a
    /// custom one in Step 3.
    ///
    /// Clears `profileImageData` first: that property is what `profilePictureSource`
    /// reads to decide `.google` vs `.custom`, so this is what "undoes" a previously
    /// picked custom photo, even before the download below finishes.
    ///
    /// Deliberately does not touch `profileImageData` afterwards, and never did:
    /// that property means "the user picked their own photo, upload it after
    /// registering". Google's picture is imported server-side from the verified
    /// token instead, so writing it here would both re-upload it and flip
    /// `profilePictureSource` back to `.custom`.
    ///
    /// Called once at init to show Google's photo up front, and again from the
    /// "Usar foto de Google" pill in Step 3 — which also doubles as the retry path
    /// if the initial silent download failed (e.g. no network yet at launch).
    public func useGooglePhoto() async {
        profileImageData = nil

        guard let urlString = googleAccount?.pictureURL,
              let url = URL(string: urlString) else { return }

        isLoadingGooglePhoto = true
        defer { isLoadingGooglePhoto = false }

        // A failed fetch leaves whatever was on screen before rather than blanking
        // the avatar — the user can just tap the pill again once they have signal.
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }

        profileImage = Image(uiImage: image)
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
        // Google accounts are stored with `password = null` — there is no field to
        // fill and nothing to validate.
        return isEmailValid
            && (isGoogleFlow || isPasswordValid)
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
            if isGoogleFlow {
                try await submitGoogleRegistration()
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

    /// Registers a Google account and lands the user straight on the success screen.
    ///
    /// There is no verification code to enter: Google already handed us a verified
    /// email, so `/auth/google/register` creates the account and returns a session
    /// in one call. Setting `isVerificationComplete` is what the container watches
    /// to show `RegistrationSuccessView`, so the code screen is bypassed entirely.
    private func submitGoogleRegistration() async throws {
        guard let registerGoogleUserUseCase else {
            throw AuthError.missingGoogleSession
        }

        try await registerGoogleUserUseCase.execute(buildGoogleRegistrationInput())
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

    /// The Google counterpart of `buildRegisterRequest`.
    ///
    /// No email and no password: the backend takes the email from the verified ID
    /// token. The phone keeps the same `cleanedPhone` shape the password sign-up
    /// sends — both land in the same `users.phone` column.
    private func buildGoogleRegistrationInput() -> GoogleRegistrationInput {
        GoogleRegistrationInput(
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
            googleIssuer: googleAccount?.issuer,
            googleSubject: googleAccount?.subject,
            googlePictureURL: googleAccount?.pictureURL
        )

        // The Google ID token is never written anywhere — the backend forbids it.
        // A resumed sign-up mints a fresh one through `refreshedIdToken()`.
        try? await useCase.execute(draft, password: password.isEmpty ? nil : password)
    }

    /// Load saved draft on initialization
    private func loadDraft() async {
        guard let useCase = getOnboardingDraftUseCase else { return }

        // The use case only hands back a draft belonging to this flow: the Google
        // identity that's signing up, or a password draft when there is none.
        if let result = try? await useCase.execute(googleIdentity: googleAccount?.draftIdentity) {
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
