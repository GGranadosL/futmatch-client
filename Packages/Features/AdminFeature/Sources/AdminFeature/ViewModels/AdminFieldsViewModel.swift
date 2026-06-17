import Foundation

@MainActor
public final class AdminFieldsViewModel: ObservableObject {

    public enum State: Equatable {
        case idle
        case loading
        case loaded([AdminFieldItem])
        case empty
        case failed(String)
    }

    @Published public private(set) var state: State = .idle

    private let fetchFieldsUseCase: FetchAdminFieldsUseCaseProtocol
    private let cacheRepo: AdminFieldsCacheRepositoryProtocol?

    public init(
        fetchFieldsUseCase: FetchAdminFieldsUseCaseProtocol,
        cacheRepo: AdminFieldsCacheRepositoryProtocol? = nil
    ) {
        self.fetchFieldsUseCase = fetchFieldsUseCase
        self.cacheRepo = cacheRepo

        // Pre-load cache synchronously so the first render already has data
        // and the skeleton only appears on truly cold loads.
        if let cached = cacheRepo?.loadFields(), !cached.isEmpty {
            state = .loaded(cached)
        }
    }

    public func load() async {
        let cached = cacheRepo?.loadFields() ?? []

        // If we already have loaded data (from cache or a previous fetch),
        // keep showing it while the network refresh runs silently in the background.
        // Only show the skeleton/loading state when there is genuinely nothing to show.
        if case .loaded = state {
            // silent refresh — state stays .loaded
        } else if !cached.isEmpty {
            state = .loaded(cached)
        } else {
            state = .loading
        }

        do {
            let fields = try await fetchFieldsUseCase.execute()
            let sorted = Self.sortedByName(fields)
            try? cacheRepo?.saveFields(sorted)
            state = sorted.isEmpty ? .empty : .loaded(sorted)
        } catch {
            // If we already have cached data, keep it visible and don't replace
            // with an error screen. Otherwise surface the error.
            if case .loaded = state { return }
            state = cached.isEmpty ? .failed(error.localizedDescription) : .loaded(cached)
        }
    }

    /// Replaces an edited field in the loaded list (and cache) so the list card
    /// reflects the change immediately, without a full network reload.
    public func applyUpdatedField(_ field: AdminFieldItem) {
        guard case .loaded(var fields) = state,
              let index = fields.firstIndex(where: { $0.id == field.id })
        else { return }
        fields[index] = field
        let sorted = Self.sortedByName(fields)
        try? cacheRepo?.saveFields(sorted)
        state = .loaded(sorted)
    }

    private static func sortedByName(_ fields: [AdminFieldItem]) -> [AdminFieldItem] {
        fields.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
