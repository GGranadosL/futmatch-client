import Foundation

// MARK: - Cancel Admin Match Error

enum CancelAdminMatchError: LocalizedError {
    case invalidReason

    var errorDescription: String? { L10n.CancelMatch.invalidReason }
}

// MARK: - Cancel Admin Match Use Case Protocol

protocol CancelAdminMatchUseCaseProtocol {
    func execute(matchId: String, reason: String) async throws
}

// MARK: - Cancel Admin Match Use Case

struct CancelAdminMatchUseCase: CancelAdminMatchUseCaseProtocol {
    /// Mirrors the backend's max length for `reason`.
    static let maxReasonLength = 300

    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(matchId: String, reason: String) async throws {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxReasonLength else {
            throw CancelAdminMatchError.invalidReason
        }
        try await repository.cancelMatch(matchId: matchId, reason: trimmed)
    }
}
