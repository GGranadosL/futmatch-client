import Foundation

/// Payment history of one user, five attempts per page (fixed by the backend).
@MainActor
public final class AdminUserPaymentsViewModel: ObservableObject {

    public enum Content: Equatable {
        case loading
        case failed(String)
        case empty
        case loaded([AdminUserPayment])
    }

    @Published public private(set) var page: AdminPage<AdminUserPayment>?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var scrollResetToken = 0

    private let userId: String
    private let fetchPaymentsUseCase: FetchAdminUserPaymentsUseCaseProtocol
    private var currentPage = 1
    private var requestID = 0

    public init(userId: String, fetchPaymentsUseCase: FetchAdminUserPaymentsUseCaseProtocol) {
        self.userId = userId
        self.fetchPaymentsUseCase = fetchPaymentsUseCase
    }

    public var pageNumber: Int { page?.page ?? currentPage }
    public var totalPages: Int { page?.totalPages ?? 1 }
    public var total: Int { page?.total ?? 0 }

    public var content: Content {
        guard let page else {
            if let errorMessage, !isLoading { return .failed(errorMessage) }
            return .loading
        }
        return page.items.isEmpty ? .empty : .loaded(page.items)
    }

    public func loadIfNeeded() async {
        guard page == nil, !isLoading else { return }
        await load()
    }

    public func refresh() async { await load() }

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

    private func load() async {
        requestID += 1
        let id = requestID
        isLoading = true
        errorMessage = nil
        do {
            let result = try await fetchPaymentsUseCase.execute(userId: userId, page: currentPage)
            guard id == requestID else { return }
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
