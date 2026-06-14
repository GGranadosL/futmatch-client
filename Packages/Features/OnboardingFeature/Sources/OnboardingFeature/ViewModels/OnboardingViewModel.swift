import Foundation
import SwiftUI
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
    @Published public var birthDate: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @Published public var gender: GenderOption? = nil
    
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
    
    // MARK: - UI State
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var showVerification: Bool = false
    @Published public var isVerificationComplete: Bool = false
    @Published public var resendCodeTimeInSeconds: Int = 60
    @Published public var isDraftRestored: Bool = false
    
    // MARK: - Use Cases
    private let registerUserUseCase: RegisterUserUseCaseProtocol
    private let verifyCodeUseCase: VerifyCodeUseCaseProtocol
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
        saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol? = nil,
        getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol? = nil,
        clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol? = nil,
        fetchCountriesUseCase: FetchCountriesUseCaseProtocol? = nil,
        fetchDialCodesUseCase: FetchDialCodesUseCaseProtocol? = nil
    ) {
        let authService = AuthService()
        self.registerUserUseCase = registerUserUseCase ?? RegisterUserUseCase(authService: authService)
        self.verifyCodeUseCase = verifyCodeUseCase ?? VerifyCodeUseCase(authService: authService)
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        self.fetchCountriesUseCase = fetchCountriesUseCase ?? FetchCountriesUseCase(repository: FallbackCountryRepository())
        self.fetchDialCodesUseCase = fetchDialCodesUseCase ?? FetchDialCodesUseCase(repository: FallbackDialCodeRepository())

        Task {
            await loadDraft()
            await loadCountries()
            await loadDialCodes()
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
        return FieldValidator.validateBirthDate(birthDate).isValid
    }
    
    // Step 2 Validations
    public var isStep2Valid: Bool {
        return isEmailValid
            && isPasswordValid
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
            let request = buildRegisterRequest()
            let result = try await registerUserUseCase.execute(request: request)
            
            if result.success {
                resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
                showVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
        let birthDateTimestamp = Int64(birthDate.timeIntervalSince1970 * 1000)

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
            currentStep: currentStep
        )
        
        try? await useCase.execute(draft, password: password.isEmpty ? nil : password)
    }
    
    /// Load saved draft on initialization
    private func loadDraft() async {
        guard let useCase = getOnboardingDraftUseCase else { return }
        
        if let result = try? await useCase.execute() {
            await restoreDraft(result.draft, password: result.password)
        }
    }
    
    /// Restore draft data to view model
    private func restoreDraft(_ draft: OnboardingDraft, password: String?) async {
        firstName = draft.firstName
        lastName = draft.lastName
        birthDate = draft.birthDate ?? self.birthDate
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
