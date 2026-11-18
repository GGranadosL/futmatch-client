import Foundation

/// State of the "Match invites" switch in Settings.
@MainActor
final class MatchInvitesPreferenceViewModel: ObservableObject {
    @Published private(set) var isEnabled = true
    /// False until the server value arrives; the switch stays disabled meanwhile so
    /// the user can't flip a value that may not be theirs.
    @Published private(set) var isLoaded = false
    @Published private(set) var isSaving = false
    /// Set when saving fails; the switch is already back on its previous value.
    @Published private(set) var errorMessage: String?

    private let getEnabledUseCase: GetMatchInvitesEnabledUseCaseProtocol
    private let setEnabledUseCase: SetMatchInvitesEnabledUseCaseProtocol

    init(
        getEnabledUseCase: GetMatchInvitesEnabledUseCaseProtocol,
        setEnabledUseCase: SetMatchInvitesEnabledUseCaseProtocol
    ) {
        self.getEnabledUseCase = getEnabledUseCase
        self.setEnabledUseCase = setEnabledUseCase
    }

    /// Reads the server value. A failure leaves the switch disabled; it's read
    /// again the next time Settings opens.
    func load() async {
        do {
            isEnabled = try await getEnabledUseCase.execute()
            isLoaded = true
        } catch {
            isLoaded = false
        }
    }

    /// Moves the switch right away and saves. On failure the switch goes back to
    /// its previous value and `errorMessage` is set.
    func setEnabled(_ enabled: Bool) async {
        guard isLoaded, !isSaving, enabled != isEnabled else { return }
        let previous = isEnabled
        isEnabled = enabled
        isSaving = true
        errorMessage = nil
        do {
            try await setEnabledUseCase.execute(enabled)
        } catch {
            isEnabled = previous
            errorMessage = error.apiErrorMessage ?? L10n.Settings.matchInvitesUpdateError
        }
        isSaving = false
    }

    func clearError() {
        errorMessage = nil
    }
}
