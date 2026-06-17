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
            state = matches.isEmpty ? .empty : .loaded(matches)
        } catch {
            if case .loaded = state { return }
            state = .failed(error.localizedDescription)
        }
    }
}
