import Foundation

@MainActor
public final class AdminHomeViewModel: ObservableObject {

    public enum State: Equatable {
        case idle
        case loading
        case loaded(AdminDashboard)
        case failed(String)
    }

    @Published public private(set) var state: State = .idle

    private let fetchDashboardUseCase: FetchAdminDashboardUseCaseProtocol

    public init(fetchDashboardUseCase: FetchAdminDashboardUseCaseProtocol) {
        self.fetchDashboardUseCase = fetchDashboardUseCase
    }

    public func load() async {
        if case .loaded = state {} else {
            state = .loading
        }
        do {
            let dashboard = try await fetchDashboardUseCase.execute()
            state = .loaded(dashboard)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
