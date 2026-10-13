import Foundation

@MainActor
final class PaymentSecurityViewModel: ObservableObject {
    @Published private(set) var isEnabled = true
    /// True while the pre-disable biometric / passcode prompt is on screen.
    @Published private(set) var isVerifying = false
    /// Set when disabling fails or is cancelled; the view surfaces it as an
    /// error toast. `isEnabled` is left untouched (still `true`) in that case.
    @Published private(set) var errorMessage: String?

    private let getEnabledUseCase: GetPaymentSecurityEnabledUseCaseProtocol
    private let setEnabledUseCase: SetPaymentSecurityEnabledUseCaseProtocol
    private let authorizeUseCase: AuthorizeSensitiveActionUseCaseProtocol

    init(
        getEnabledUseCase: GetPaymentSecurityEnabledUseCaseProtocol,
        setEnabledUseCase: SetPaymentSecurityEnabledUseCaseProtocol,
        authorizeUseCase: AuthorizeSensitiveActionUseCaseProtocol
    ) {
        self.getEnabledUseCase = getEnabledUseCase
        self.setEnabledUseCase = setEnabledUseCase
        self.authorizeUseCase = authorizeUseCase
    }

    /// Refreshes `isEnabled` from the persisted preference. Call once when
    /// Settings appears.
    func load() {
        isEnabled = getEnabledUseCase.execute()
    }

    /// Turning ON never gates — persists immediately.
    func enable() {
        setEnabledUseCase.execute(true)
        isEnabled = true
    }

    /// Turning OFF must pass the biometric / passcode gate first. On success,
    /// persists `false`. On failure/cancel, `isEnabled` stays `true` — the
    /// view's toggle binding reads it back, so the switch visually snaps back
    /// to ON with no extra revert code in the view.
    func disable() async {
        isVerifying = true
        errorMessage = nil
        do {
            try await authorizeUseCase.execute(reason: L10n.Settings.paymentSecurityBiometricReason)
            setEnabledUseCase.execute(false)
            isEnabled = false
        } catch {
            errorMessage = L10n.Settings.paymentSecurityBiometricFailedError
        }
        isVerifying = false
    }

    func clearError() {
        errorMessage = nil
    }
}
