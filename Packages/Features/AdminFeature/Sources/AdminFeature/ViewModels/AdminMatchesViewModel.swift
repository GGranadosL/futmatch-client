import Foundation

@MainActor
final class AdminMatchesViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case loaded([AdminMatch])
        case empty
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let fetchUseCase: FetchAdminMatchesUseCaseProtocol

    init(fetchUseCase: FetchAdminMatchesUseCaseProtocol) {
        self.fetchUseCase = fetchUseCase
    }

    func load() async {
        if case .loaded = state { /* silent refresh — keep showing data */ } else { state = .loading }
        do {
            let matches = try await fetchUseCase.execute()
            let newState: State = matches.isEmpty ? .empty : .loaded(matches)
            // Skip identical publishes: a silent refresh with unchanged data
            // would otherwise re-render the whole list for nothing.
            if newState != state { state = newState }
        } catch {
            if case .loaded = state { return }
            state = .failed(error.localizedDescription)
        }
    }
}
