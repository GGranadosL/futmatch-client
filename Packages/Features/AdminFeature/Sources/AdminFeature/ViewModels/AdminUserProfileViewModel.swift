import Foundation

/// Admin view of one user: detail, devices and the "manage access" sheet.
@MainActor
public final class AdminUserProfileViewModel: ObservableObject {

    public enum State: Equatable {
        case loading
        case loaded(AdminUserDetail)
        case failed(String)
    }

    @Published public private(set) var state: State = .loading
    /// Error from a refresh while data is already on screen (shown as a toast).
    @Published public private(set) var refreshError: String?

    // Access sheet
    @Published public var draftRole: AdminUserRole = .player
    @Published public var draftStatus: AdminUserStatus = .active
    @Published public private(set) var isSavingAccess = false
    @Published public private(set) var accessError: String?
    /// Flips to true once per successful save; the view shows the toast and resets it.
    @Published public private(set) var accessSaved = false

    public let userId: String
    private let currentUserId: String?
    private let fetchDetailUseCase: FetchAdminUserDetailUseCaseProtocol
    private let updateAccessUseCase: UpdateAdminUserAccessUseCaseProtocol

    public init(
        userId: String,
        currentUserId: String?,
        fetchDetailUseCase: FetchAdminUserDetailUseCaseProtocol,
        updateAccessUseCase: UpdateAdminUserAccessUseCaseProtocol
    ) {
        self.userId = userId
        self.currentUserId = currentUserId
        self.fetchDetailUseCase = fetchDetailUseCase
        self.updateAccessUseCase = updateAccessUseCase
    }

    // MARK: Derived

    public var detail: AdminUserDetail? {
        if case let .loaded(detail) = state { return detail }
        return nil
    }

    /// An admin can't change their own access here (the server rejects it too).
    public var canManageAccess: Bool {
        guard let currentUserId, !currentUserId.isEmpty else { return detail != nil }
        return detail != nil && currentUserId != userId
    }

    public var hasAccessChanges: Bool {
        guard let summary = detail?.summary else { return false }
        return AdminUserAccessChange.diff(
            currentRole: summary.role, currentStatus: summary.status,
            newRole: draftRole, newStatus: draftStatus
        ) != nil
    }

    public var canSaveAccess: Bool { hasAccessChanges && !isSavingAccess && canManageAccess }

    // MARK: Loading

    public func load() async {
        if detail == nil { state = .loading }
        refreshError = nil
        do {
            let detail = try await fetchDetailUseCase.execute(userId: userId)
            state = .loaded(detail)
        } catch {
            if error is CancellationError { return }
            if detail != nil {
                refreshError = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: Access

    /// Seeds the sheet with the user's current values.
    public func beginEditingAccess() {
        guard let summary = detail?.summary else { return }
        draftRole = summary.role == .unknown ? .player : summary.role
        draftStatus = summary.status == .unknown ? .active : summary.status
        accessError = nil
        accessSaved = false
    }

    public func saveAccess() async {
        guard let summary = detail?.summary, canSaveAccess else { return }
        isSavingAccess = true
        accessError = nil
        defer { isSavingAccess = false }
        do {
            try await updateAccessUseCase.execute(
                userId: userId,
                currentRole: summary.role, currentStatus: summary.status,
                newRole: draftRole, newStatus: draftStatus
            )
            if let detail { state = .loaded(detail.withAccess(role: draftRole, status: draftStatus)) }
            accessSaved = true
            // Re-read from the server: sessions were revoked and other fields may change.
            await load()
        } catch {
            if error is CancellationError { return }
            accessError = error.localizedDescription
        }
    }

    public func acknowledgeAccessSaved() {
        accessSaved = false
    }

    public func clearAccessError() {
        accessError = nil
    }
}
