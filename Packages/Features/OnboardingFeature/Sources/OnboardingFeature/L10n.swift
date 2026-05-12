import Foundation

/// Localized strings for Onboarding
public enum L10n {
    
    // MARK: - Step Counter
    public static func stepCounter(_ current: Int, _ total: Int) -> String {
        String(format: NSLocalizedString("onboarding.step.counter", bundle: .module, comment: ""), current, total)
    }
    
    // MARK: - Step 1: Personal Info
    public enum Step1 {
        public static var title: String {
            NSLocalizedString("onboarding.step1.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("onboarding.step1.subtitle", bundle: .module, comment: "")
        }
        public static var firstName: String {
            NSLocalizedString("onboarding.step1.firstName", bundle: .module, comment: "")
        }
        public static var lastName: String {
            NSLocalizedString("onboarding.step1.lastName", bundle: .module, comment: "")
        }
        public static var dateOfBirth: String {
            NSLocalizedString("onboarding.step1.dateOfBirth", bundle: .module, comment: "")
        }
        public static var gender: String {
            NSLocalizedString("onboarding.step1.gender", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Step 2: Contact & Account
    public enum Step2 {
        public static var title: String {
            NSLocalizedString("onboarding.step2.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("onboarding.step2.subtitle", bundle: .module, comment: "")
        }
        public static var email: String {
            NSLocalizedString("onboarding.step2.email", bundle: .module, comment: "")
        }
        public static var password: String {
            NSLocalizedString("onboarding.step2.password", bundle: .module, comment: "")
        }
        public static var countryCode: String {
            NSLocalizedString("onboarding.step2.countryCode", bundle: .module, comment: "")
        }
        public static var phone: String {
            NSLocalizedString("onboarding.step2.phone", bundle: .module, comment: "")
        }
        public static var country: String {
            NSLocalizedString("onboarding.step2.country", bundle: .module, comment: "")
        }
        public static var countryCodePlaceholder: String {
            NSLocalizedString("onboarding.step2.placeholder.countryCode", bundle: .module, comment: "")
        }
        public static var countryPlaceholder: String {
            NSLocalizedString("onboarding.step2.placeholder.country", bundle: .module, comment: "")
        }
        public static var invalidEmail: String {
            NSLocalizedString("onboarding.step2.error.invalidEmail", bundle: .module, comment: "")
        }
        public static var passwordMinLength: String {
            NSLocalizedString("onboarding.step2.error.passwordMinLength", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Step 3: Football Profile
    public enum Step3 {
        public static var title: String {
            NSLocalizedString("onboarding.step3.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("onboarding.step3.subtitle", bundle: .module, comment: "")
        }
        public static var uploadPhoto: String {
            NSLocalizedString("onboarding.step3.uploadPhoto", bundle: .module, comment: "")
        }
        public static var mainPosition: String {
            NSLocalizedString("onboarding.step3.mainPosition", bundle: .module, comment: "")
        }
        public static var takePhoto: String {
            NSLocalizedString("onboarding.step3.takePhoto", bundle: .module, comment: "")
        }
        public static var chooseFromGallery: String {
            NSLocalizedString("onboarding.step3.chooseFromGallery", bundle: .module, comment: "")
        }
        public static var cancel: String {
            NSLocalizedString("onboarding.step3.cancel", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Step 4: Review & Confirm
    public enum Step4 {
        public static var title: String {
            NSLocalizedString("onboarding.step4.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("onboarding.step4.subtitle", bundle: .module, comment: "")
        }
        public static var identity: String {
            NSLocalizedString("onboarding.step4.identity", bundle: .module, comment: "")
        }
        public static var personalInfo: String {
            NSLocalizedString("onboarding.step4.personalInfo", bundle: .module, comment: "")
        }
        public static var contact: String {
            NSLocalizedString("onboarding.step4.contact", bundle: .module, comment: "")
        }
        public static var birthDate: String {
            NSLocalizedString("onboarding.step4.birthDate", bundle: .module, comment: "")
        }
        public static var edit: String {
            NSLocalizedString("onboarding.step4.edit", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Gender Options
    public enum Gender {
        public static var male: String {
            NSLocalizedString("onboarding.gender.male", bundle: .module, comment: "")
        }
        public static var female: String {
            NSLocalizedString("onboarding.gender.female", bundle: .module, comment: "")
        }
        public static var other: String {
            NSLocalizedString("onboarding.gender.other", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Position Options
    public enum Position {
        public static var goalkeeper: String {
            NSLocalizedString("onboarding.position.goalkeeper", bundle: .module, comment: "")
        }
        public static var defender: String {
            NSLocalizedString("onboarding.position.defender", bundle: .module, comment: "")
        }
        public static var midfielder: String {
            NSLocalizedString("onboarding.position.midfielder", bundle: .module, comment: "")
        }
        public static var forward: String {
            NSLocalizedString("onboarding.position.forward", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Buttons
    public enum Button {
        public static var nextStep: String {
            NSLocalizedString("onboarding.button.nextStep", bundle: .module, comment: "")
        }
        public static var createAccount: String {
            NSLocalizedString("onboarding.button.createAccount", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Terms
    public enum Terms {
        public static var prefix: String {
            NSLocalizedString("onboarding.terms.prefix", bundle: .module, comment: "")
        }
        public static var termsOfService: String {
            NSLocalizedString("onboarding.terms.termsOfService", bundle: .module, comment: "")
        }
        public static var and: String {
            NSLocalizedString("onboarding.terms.and", bundle: .module, comment: "")
        }
        public static var privacyPolicy: String {
            NSLocalizedString("onboarding.terms.privacyPolicy", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Login
    public enum Login {
        public static var title: String {
            NSLocalizedString("login.title", bundle: .module, comment: "")
        }
        public static var email: String {
            NSLocalizedString("login.email", bundle: .module, comment: "")
        }
        public static var password: String {
            NSLocalizedString("login.password", bundle: .module, comment: "")
        }
        public static var forgotPassword: String {
            NSLocalizedString("login.forgotPassword", bundle: .module, comment: "")
        }
        public static var button: String {
            NSLocalizedString("login.button", bundle: .module, comment: "")
        }
        public static var noAccount: String {
            NSLocalizedString("login.noAccount", bundle: .module, comment: "")
        }
        public static var createAccount: String {
            NSLocalizedString("login.createAccount", bundle: .module, comment: "")
        }
        public static var errorTitle: String {
            NSLocalizedString("login.error.title", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Forgot Password
    public enum ForgotPassword {
        public static var title: String {
            NSLocalizedString("forgotPassword.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("forgotPassword.subtitle", bundle: .module, comment: "")
        }
        public static var navTitle: String {
            NSLocalizedString("forgotPassword.navTitle", bundle: .module, comment: "")
        }
        public static var sendButton: String {
            NSLocalizedString("forgotPassword.sendButton", bundle: .module, comment: "")
        }
        public static var successTitle: String {
            NSLocalizedString("forgotPassword.success.title", bundle: .module, comment: "")
        }
        public static var successMessage: String {
            NSLocalizedString("forgotPassword.success.message", bundle: .module, comment: "")
        }
        
        // MARK: - Verification
        public static var verificationTitle: String {
            NSLocalizedString("forgotPassword.verification.title", bundle: .module, comment: "")
        }
        public static var verificationSubtitle: String {
            NSLocalizedString("forgotPassword.verification.subtitle", bundle: .module, comment: "")
        }
        public static var confirmButton: String {
            NSLocalizedString("forgotPassword.verification.confirmButton", bundle: .module, comment: "")
        }
        public static var resendTimer: String {
            NSLocalizedString("forgotPassword.verification.resendTimer", bundle: .module, comment: "")
        }
        public static var resendCode: String {
            NSLocalizedString("forgotPassword.verification.resendCode", bundle: .module, comment: "")
        }
        
        // MARK: - New Password
        public static var newPasswordTitle: String {
            NSLocalizedString("forgotPassword.newPassword.title", bundle: .module, comment: "")
        }
        public static var newPasswordSubtitle: String {
            NSLocalizedString("forgotPassword.newPassword.subtitle", bundle: .module, comment: "")
        }
        public static var newPasswordLabel: String {
            NSLocalizedString("forgotPassword.newPassword.newPasswordLabel", bundle: .module, comment: "")
        }
        public static var confirmPasswordLabel: String {
            NSLocalizedString("forgotPassword.newPassword.confirmPasswordLabel", bundle: .module, comment: "")
        }
        public static var resetButton: String {
            NSLocalizedString("forgotPassword.newPassword.resetButton", bundle: .module, comment: "")
        }
        
        // MARK: - Success
        public static var successCompleteTitle: String {
            NSLocalizedString("forgotPassword.successComplete.title", bundle: .module, comment: "")
        }
        public static var successCompleteMessage: String {
            NSLocalizedString("forgotPassword.successComplete.message", bundle: .module, comment: "")
        }
        public static var doneButton: String {
            NSLocalizedString("forgotPassword.successComplete.doneButton", bundle: .module, comment: "")
        }
        
        // MARK: - Common
        public static var cancel: String {
            NSLocalizedString("forgotPassword.cancel", bundle: .module, comment: "")
        }
        public static var emailLabel: String {
            NSLocalizedString("forgotPassword.emailLabel", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Common
    public enum Common {
        public static var ok: String {
            NSLocalizedString("common.ok", bundle: .module, comment: "")
        }
    }
    
    // MARK: - MFA
    public enum MFA {
        public static var title: String {
            NSLocalizedString("mfa.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("mfa.subtitle", bundle: .module, comment: "")
        }
        public static var verify: String {
            NSLocalizedString("mfa.verify", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Verification
    public enum Verification {
        public static var title: String {
            NSLocalizedString("verification.title", bundle: .module, comment: "")
        }
        public static var subtitle: String {
            NSLocalizedString("verification.subtitle", bundle: .module, comment: "")
        }
        public static var instruction: String {
            NSLocalizedString("verification.instruction", bundle: .module, comment: "")
        }
        public static var navTitle: String {
            NSLocalizedString("verification.navTitle", bundle: .module, comment: "")
        }
        public static var confirm: String {
            NSLocalizedString("verification.confirm", bundle: .module, comment: "")
        }
        public static func resendIn(_ seconds: Int) -> String {
            String(format: NSLocalizedString("verification.resendIn", bundle: .module, comment: ""), seconds)
        }
        public static var didntReceive: String {
            NSLocalizedString("verification.didntReceive", bundle: .module, comment: "")
        }
        public static var resend: String {
            NSLocalizedString("verification.resend", bundle: .module, comment: "")
        }
    }
    
    // MARK: - Validation Messages
    public enum Validation {
        public static func maxCharacters(_ count: Int) -> String {
            String(format: NSLocalizedString("validation.maxCharacters", bundle: .module, comment: ""), count)
        }
        public static var onlyLetters: String {
            NSLocalizedString("validation.onlyLetters", bundle: .module, comment: "")
        }
        public static func minimumAge(_ age: Int) -> String {
            String(format: NSLocalizedString("validation.minimumAge", bundle: .module, comment: ""), age)
        }
        public static var invalidPhone: String {
            NSLocalizedString("validation.invalidPhone", bundle: .module, comment: "")
        }
        public static var invalidEmail: String {
            NSLocalizedString("validation.invalidEmail", bundle: .module, comment: "")
        }
        public static var fieldRequired: String {
            NSLocalizedString("validation.fieldRequired", bundle: .module, comment: "")
        }
        public static var invalidUUID: String {
            NSLocalizedString("validation.invalidUUID", bundle: .module, comment: "")
        }
        public static var codeRequired: String {
            NSLocalizedString("validation.codeRequired", bundle: .module, comment: "")
        }
        
        // Password validation
        public static var minPasswordLength: String {
            NSLocalizedString("validation.minPasswordLength", bundle: .module, comment: "")
        }
        public static var requiresUppercase: String {
            NSLocalizedString("validation.requiresUppercase", bundle: .module, comment: "")
        }
        public static var requiresLowercase: String {
            NSLocalizedString("validation.requiresLowercase", bundle: .module, comment: "")
        }
        public static var requiresNumber: String {
            NSLocalizedString("validation.requiresNumber", bundle: .module, comment: "")
        }
        public static var requiresSpecialChar: String {
            NSLocalizedString("validation.requiresSpecialChar", bundle: .module, comment: "")
        }
        public static var passwordsDoNotMatch: String {
            NSLocalizedString("validation.passwordsDoNotMatch", bundle: .module, comment: "")
        }
    }
}
