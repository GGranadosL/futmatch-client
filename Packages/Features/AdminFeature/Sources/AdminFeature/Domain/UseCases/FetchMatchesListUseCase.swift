import Foundation

/// Shared shape of the match-list sources backing `AdminMatchesViewModel`.
/// The role decides which one is wired in: admins read `/match/admin/matches`
/// via `FetchAdminMatchesUseCase`, organizers read `/match/organizer/matches`
/// via `FetchOrganizerMatchesUseCase`.
public protocol FetchMatchesListUseCaseProtocol {
    func execute() async throws -> [AdminMatch]
}
