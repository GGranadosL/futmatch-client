import Foundation

/// Paged list of users for one role, plus a name filter that only looks at the
/// loaded page (the backend has no search).
@MainActor
public final class AdminUsersViewModel: ObservableObject {

    public enum Content: Equatable {
        /// First load with nothing to show: skeleton.
        case loading
        case failed(String)
        /// The role has no users at all.
        case empty
        /// The page has users but none matches the search.
        case noMatches
        case loaded([AdminUserSummary])
    }

    @Published public private(set) var selectedRole: AdminUserRole = .administrator
    @Published public private(set) var page: AdminPage<AdminUserSummary>?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var searchQuery = ""
    /// Bumped on role/page changes so the view scrolls back to the top.
    @Published public private(set) var scrollResetToken = 0

    private let fetchUsersUseCase: FetchAdminUsersUseCaseProtocol
    private var currentPage = 1
    private var requestID = 0

    public init(fetchUsersUseCase: FetchAdminUsersUseCaseProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    // MARK: Derived

    public var pageNumber: Int { page?.page ?? currentPage }
    public var totalPages: Int { page?.totalPages ?? 1 }
    public var totalUsers: Int { page?.total ?? 0 }
    public var isSearching: Bool { !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    public var visibleUsers: [AdminUserSummary] {
        (page?.items ?? []).filter { AdminUsersFormatting.nameMatches($0.fullName, query: searchQuery) }
    }

    public var content: Content {
        guard let page else {
            if let errorMessage, !isLoading { return .failed(errorMessage) }
            return .loading
        }
        if page.items.isEmpty { return .empty }
        let visible = visibleUsers
        return visible.isEmpty ? .noMatches : .loaded(visible)
    }

    // MARK: Actions

    public func loadIfNeeded() async {
        guard page == nil, !isLoading else { return }
        await load()
    }

    public func refresh() async {
        await load()
    }

    public func selectRole(_ role: AdminUserRole) async {
        guard role != selectedRole else { return }
        selectedRole = role
        currentPage = 1
        page = nil // the old role's users must not show under the new tab
        scrollResetToken += 1
        await load()
    }

    public func nextPage() async {
        guard pageNumber < totalPages, !isLoading else { return }
        currentPage = pageNumber + 1
        scrollResetToken += 1
        await load()
    }

    public func previousPage() async {
        guard pageNumber > 1, !isLoading else { return }
        currentPage = pageNumber - 1
        scrollResetToken += 1
        await load()
    }

    public func clearSearch() {
        searchQuery = ""
    }

    // MARK: Loading

    private func load() async {
        requestID += 1
        let id = requestID
        let role = selectedRole
        let pageToLoad = currentPage
        isLoading = true
        errorMessage = nil
        do {
            let result = try await fetchUsersUseCase.execute(role: role, page: pageToLoad)
            guard id == requestID else { return } // a newer request owns the state
            // If users were removed and this page is now past the end, step back.
            if result.items.isEmpty, pageToLoad > 1, result.total > 0 {
                currentPage = result.totalPages
                isLoading = false
                await load()
                return
            }
            page = result
            currentPage = result.page
            isLoading = false
        } catch {
            guard id == requestID else { return }
            isLoading = false
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }
}
