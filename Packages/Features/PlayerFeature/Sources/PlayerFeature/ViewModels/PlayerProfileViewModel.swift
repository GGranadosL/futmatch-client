import Foundation
import SharedModels

@MainActor
final class PlayerProfileViewModel: ObservableObject {

    enum State {
        case loading
        case loaded(PublicPlayerProfile)
        case failed(String)
    }

    @Published private(set) var state: State = .loading

    private let userId: String
    private let profileService: ProfileServiceProtocol

    init(userId: String, profileService: ProfileServiceProtocol) {
        self.userId = userId
        self.profileService = profileService
    }

    func load() async {
        state = .loading
        do {
            let profile = try await profileService.fetchPublicProfile(userId: userId)
            state = .loaded(profile)
        } catch {
            guard !(error is CancellationError) else { return }
            state = .failed(error.localizedDescription)
        }
    }

    /// Silent reload for pull-to-refresh — keeps the current content visible
    /// (no skeleton flash) and only swaps in fresh data on success.
    func refresh() async {
        do {
            let profile = try await profileService.fetchPublicProfile(userId: userId)
            state = .loaded(profile)
        } catch {
            // Keep showing the existing content on a failed refresh.
        }
    }
}
