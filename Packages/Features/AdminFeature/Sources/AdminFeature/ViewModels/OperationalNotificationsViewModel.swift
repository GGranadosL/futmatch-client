import Foundation

/// Hub for one operational inbox (ADMIN or ORGANIZER).
@MainActor
public final class OperationalNotificationsViewModel: ObservableObject {

    public enum Content: Equatable {
        case loading
        case failed(String)
        case empty
        case loaded([OperationalNotification])
    }

    @Published public private(set) var notifications: [OperationalNotification]?
    @Published public private(set) var isLoading = false
    @Published public private(set) var loadError: String?
    @Published public private(set) var deletingIds: Set<String> = []
    /// Transient errors (read-all, delete, open match) shown as toasts.
    @Published public private(set) var toastError: String?
    @Published public private(set) var isOpeningMatch = false
    /// Set when a tap resolved its match; the view pushes the detail and clears it.
    @Published public private(set) var matchToOpen: AdminMatch?

    public let inbox: OperationalInbox
    private let store: OperationalNotificationsStore
    private let openInboxUseCase: OpenOperationalInboxUseCaseProtocol
    private let deleteUseCase: DeleteOperationalNotificationUseCaseProtocol
    private let findMatchUseCase: FindOperationalMatchUseCaseProtocol
    private let matchUnavailableMessage: String

    public init(
        inbox: OperationalInbox,
        store: OperationalNotificationsStore,
        openInboxUseCase: OpenOperationalInboxUseCaseProtocol,
        deleteUseCase: DeleteOperationalNotificationUseCaseProtocol,
        findMatchUseCase: FindOperationalMatchUseCaseProtocol,
        matchUnavailableMessage: String
    ) {
        self.inbox = inbox
        self.store = store
        self.openInboxUseCase = openInboxUseCase
        self.deleteUseCase = deleteUseCase
        self.findMatchUseCase = findMatchUseCase
        self.matchUnavailableMessage = matchUnavailableMessage
    }

    public var content: Content {
        guard let notifications else {
            if let loadError, !isLoading { return .failed(loadError) }
            return .loading
        }
        return notifications.isEmpty ? .empty : .loaded(notifications)
    }

    /// Open and pull-to-refresh. A second call while one runs is ignored.
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let snapshot = try await openInboxUseCase.execute(
                inbox: inbox,
                knownUnreadCount: store.count(for: inbox)
            )
            notifications = snapshot.items
            if let count = snapshot.reconciledUnreadCount {
                store.set(count, for: inbox)
            }
            if snapshot.markReadFailed {
                toastError = snapshot.markReadErrorMessage
            }
        } catch {
            if error is CancellationError { return }
            if notifications == nil {
                loadError = error.localizedDescription
            } else {
                toastError = error.localizedDescription
            }
        }
    }

    public func delete(id: String) async {
        guard !deletingIds.contains(id) else { return }
        deletingIds.insert(id)
        defer { deletingIds.remove(id) }
        do {
            try await deleteUseCase.execute(id: id, inbox: inbox)
            notifications?.removeAll { $0.id == id }
        } catch {
            if error is CancellationError { return }
            toastError = error.localizedDescription
        }
    }

    public func open(_ notification: OperationalNotification) async {
        guard let matchId = notification.matchId, !isOpeningMatch else { return }
        isOpeningMatch = true
        defer { isOpeningMatch = false }
        do {
            if let match = try await findMatchUseCase.execute(matchId: matchId, inbox: inbox) {
                matchToOpen = match
            } else {
                toastError = matchUnavailableMessage
            }
        } catch {
            if error is CancellationError { return }
            toastError = error.localizedDescription
        }
    }

    public func didOpenMatch() { matchToOpen = nil }
    public func clearToast() { toastError = nil }
}
