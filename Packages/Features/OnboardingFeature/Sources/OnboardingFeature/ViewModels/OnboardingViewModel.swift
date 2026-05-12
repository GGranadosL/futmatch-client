import Foundation
import SwiftUI
import Combine
import PersistenceFramework

/// ViewModel for the entire Onboarding flow
@MainActor
public class OnboardingViewModel: ObservableObject {
    // MARK: - Navigation
    @Published public var currentStep: Int = 1
    
    // MARK: - Step 1: Personal Info
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    @Published public var birthDate: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @Published public var gender: GenderOption = .male
    
    // MARK: - Step 2: Contact & Account
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var countryCode: String = ""
    @Published public var phone: String = ""
    @Published public var country: String = ""
    
    // MARK: - Step 3: Football Profile
    @Published public var profilePicURL: String = ""
    @Published public var profileImage: Image? = nil
    @Published public var playerPosition: PositionOption = .midfielder
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
    
    // MARK: - Auto-save
    private var saveDraftTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(
        registerUserUseCase: RegisterUserUseCaseProtocol? = nil,
        verifyCodeUseCase: VerifyCodeUseCaseProtocol? = nil,
        saveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol? = nil,
        getOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol? = nil,
        clearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol? = nil
    ) {
        let authService = AuthService()
        self.registerUserUseCase = registerUserUseCase ?? RegisterUserUseCase(authService: authService)
        self.verifyCodeUseCase = verifyCodeUseCase ?? VerifyCodeUseCase(authService: authService)
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        
        // Load saved draft on initialization
        Task {
            await loadDraft()
        }
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
    
    // MARK: - Validations
    
    // Step 1 Validations
    public var isStep1Valid: Bool {
        isFirstNameValid && isLastNameValid && isBirthDateValid
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
        let valid = isEmailValid && isPasswordValid && isPhoneValid && !country.isEmpty
        #if DEBUG
        if !valid {
            print("📋 Step2 Validation:")
            print("  - Email valid: \(isEmailValid) (\(email))")
            print("  - Password valid: \(isPasswordValid) (\(password.count) chars)")
            print("  - Phone valid: \(isPhoneValid) (\(cleanedPhone))")
            print("  - Country: \(!country.isEmpty) (\(country))")
        }
        #endif
        return valid
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
        true // Position and level have defaults, profilePic is optional
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
                print("✅ Registration successful, navigating to verification...")
                showVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Registration error: \(error.localizedDescription)")
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
                print("✅ Verification successful!")
                print("📦 User ID: \(result.userId)")
                print("🔑 Tokens saved to Keychain")
                
                // Clear draft after successful registration
                await clearDraftAfterSuccess()
                
                // Navigate to Home
                isVerificationComplete = true
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Verification error: \(error)")
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
        
        return RegisterStartRequest(
            name: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            phone: cleanedPhone,
            country: country,
            birthDate: birthDateTimestamp,
            gender: gender.toGender(),
            playerPosition: playerPosition.toPlayerPosition(),
            profilePic: profilePicURL.isEmpty ? nil : profilePicURL,
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
            gender: gender.rawValue,
            email: email,
            phoneCountryCode: countryCode,
            phone: phone,
            country: country,
            currentStep: currentStep
        )
        
        do {
            try await useCase.execute(draft, password: password.isEmpty ? nil : password)
        } catch {
            print("⚠️ Failed to save onboarding draft: \(error)")
        }
    }
    
    /// Load saved draft on initialization
    private func loadDraft() async {
        guard let useCase = getOnboardingDraftUseCase else { return }
        
        do {
            if let result = try await useCase.execute() {
                await restoreDraft(result.draft, password: result.password)
            }
        } catch {
            print("⚠️ Failed to load onboarding draft: \(error)")
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
        currentStep = draft.currentStep
        self.password = password ?? ""
        isDraftRestored = true
    }
    
    /// Clear draft after successful registration
    public func clearDraftAfterSuccess() async {
        guard let useCase = clearOnboardingDraftUseCase else { return }
        
        do {
            try await useCase.execute()
        } catch {
            print("⚠️ Failed to clear onboarding draft: \(error)")
        }
    }
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
