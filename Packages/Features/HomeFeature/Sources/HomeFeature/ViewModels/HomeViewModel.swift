import Foundation
import NetworkFramework

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var greetingName: String = ""
    @Published private(set) var level: String = ""
    @Published private(set) var averageScore: Int = 0
    @Published private(set) var profileImageUrl: String?
    @Published private(set) var suggestedMatches: [MatchItem] = []
    @Published private(set) var lastMatch: LastMatch?
    @Published private(set) var isLoading: Bool = false

    private let homeService: HomeServiceProtocol

    init(homeService: HomeServiceProtocol = HomeService()) {
        self.homeService = homeService
    }

    func load() async {
        isLoading = true
        do {
            let data = try await homeService.fetchHome()
            greetingName = data.greetingName
            level = data.level
            averageScore = data.averageScore
            profileImageUrl = data.profileImageUrl
            suggestedMatches = data.suggestedMatches
            lastMatch = data.lastMatch
        } catch {
            #if DEBUG
            print("❌ HomeViewModel: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
    }
}
