import Foundation
import NetworkFramework

// MARK: - DesktopEnrollmentApprovalState

enum DesktopEnrollmentApprovalState: Equatable {
    /// Scanning; nothing in flight.
    case idle
    case loadingDetails
    /// Waiting on the administrator to authorize or dismiss.
    case confirmation(DesktopEnrollment)
    case approving(DesktopEnrollment)

    var enrollment: DesktopEnrollment? {
        switch self {
        case let .confirmation(enrollment), let .approving(enrollment):
            return enrollment
        case .idle, .loadingDetails:
            return nil
        }
    }

    var isApproving: Bool {
        if case .approving = self { return true }
        return false
    }

    /// The camera should stop reporting scans whenever anything else is going on.
    var isBusy: Bool { self != .idle }
}

// MARK: - DesktopEnrollmentViewModel

/// Drives the scan → fetch details → confirm → approve flow.
///
/// The ticket lives only inside `state` for the lifetime of this object; it is
/// never persisted or logged.
@MainActor
final class DesktopEnrollmentViewModel: ObservableObject {

    @Published private(set) var state: DesktopEnrollmentApprovalState = .idle
    @Published private(set) var didApprove = false

    /// Toast on the scanner screen (bad QR, failed lookup).
    @Published var errorMessage: String?
    /// Toast inside the confirmation sheet — a sheet covers the presenter's own
    /// overlays, so approval failures have to surface there.
    @Published var sheetErrorMessage: String?

    private let fetchDetailsUseCase: FetchDesktopEnrollmentDetailsUseCaseProtocol
    private let approveUseCase: ApproveDesktopEnrollmentUseCaseProtocol

    init(
        fetchDetailsUseCase: FetchDesktopEnrollmentDetailsUseCaseProtocol,
        approveUseCase: ApproveDesktopEnrollmentUseCaseProtocol
    ) {
        self.fetchDetailsUseCase = fetchDetailsUseCase
        self.approveUseCase = approveUseCase
    }

    var isShowingConfirmation: Bool { state.enrollment != nil }

    // MARK: - Scanning

    func handleScan(_ payload: String) async {
        // A code sitting in frame keeps firing; ignore anything that arrives
        // while a lookup, the sheet, or an approval is already up.
        guard state == .idle else { return }

        state = .loadingDetails
        errorMessage = nil
        do {
            let enrollment = try await fetchDetailsUseCase.execute(qrPayload: payload)
            state = .confirmation(enrollment)
        } catch {
            // Back to .idle so the admin can simply scan again.
            state = .idle
            errorMessage = scanErrorMessage(for: error)
        }
    }

    // MARK: - Approval

    func approve() async {
        guard case let .confirmation(enrollment) = state else { return }

        state = .approving(enrollment)
        sheetErrorMessage = nil
        do {
            try await approveUseCase.execute(ticket: enrollment.ticket)
            didApprove = true
        } catch {
            // Stay on the sheet so the admin sees why and can retry.
            state = .confirmation(enrollment)
            sheetErrorMessage = error.apiErrorMessage ?? error.localizedDescription
        }
    }

    /// Dismisses the confirmation without contacting the backend.
    func cancelConfirmation() {
        guard !state.isApproving else { return }
        state = .idle
        sheetErrorMessage = nil
    }

    // MARK: - Private

    /// A missing enrollment and a malformed payload are the same story for the
    /// admin: this QR is no good, scan a fresh one. The backend discards the
    /// body on 404, so there is no server message to show in that case.
    private func scanErrorMessage(for error: Error) -> String {
        if error is DesktopEnrollmentError { return L10n.DesktopEnrollment.invalidQR }
        if case APIError.notFound = error { return L10n.DesktopEnrollment.invalidQR }
        return error.apiErrorMessage ?? error.localizedDescription
    }
}
