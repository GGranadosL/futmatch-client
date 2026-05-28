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
            state = .failed(error.localizedDescription)
        }
    }
}
