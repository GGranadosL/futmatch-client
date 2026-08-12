import Foundation
import NetworkFramework

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var succeeded = false

    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol

    init(deleteAccountUseCase: DeleteAccountUseCaseProtocol) {
        self.deleteAccountUseCase = deleteAccountUseCase
    }

    func deleteAccount(password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await deleteAccountUseCase.execute(password: password)
            succeeded = true
        } catch {
            errorMessage = error.apiErrorMessage ?? L10n.DeleteAccount.genericError
        }
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }
}
