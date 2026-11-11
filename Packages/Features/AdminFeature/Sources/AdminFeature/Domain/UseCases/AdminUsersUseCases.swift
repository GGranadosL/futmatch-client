import Foundation

// MARK: - Fetch users

public protocol FetchAdminUsersUseCaseProtocol {
    func execute(role: AdminUserRole, page: Int) async throws -> AdminPage<AdminUserSummary>
}

public struct FetchAdminUsersUseCase: FetchAdminUsersUseCaseProtocol {
    private let repository: AdminUsersRepositoryProtocol

    public init(repository: AdminUsersRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(role: AdminUserRole, page: Int) async throws -> AdminPage<AdminUserSummary> {
        try await repository.fetchUsers(role: role, page: max(page, 1))
    }
}

// MARK: - Fetch detail

public protocol FetchAdminUserDetailUseCaseProtocol {
    func execute(userId: String) async throws -> AdminUserDetail
}

public struct FetchAdminUserDetailUseCase: FetchAdminUserDetailUseCaseProtocol {
    private let repository: AdminUsersRepositoryProtocol

    public init(repository: AdminUsersRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: String) async throws -> AdminUserDetail {
        try await repository.fetchUserDetail(userId: userId)
    }
}

// MARK: - Payment history

public protocol FetchAdminUserPaymentsUseCaseProtocol {
    func execute(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment>
}

public struct FetchAdminUserPaymentsUseCase: FetchAdminUserPaymentsUseCaseProtocol {
    private let repository: AdminUsersRepositoryProtocol

    public init(repository: AdminUsersRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment> {
        try await repository.fetchPaymentHistory(userId: userId, page: max(page, 1))
    }
}

// MARK: - Update access

public protocol UpdateAdminUserAccessUseCaseProtocol {
    /// Sends only what changed. Throws `AdminUsersError.noAccessChanges` when nothing did.
    func execute(
        userId: String,
        currentRole: AdminUserRole, currentStatus: AdminUserStatus,
        newRole: AdminUserRole, newStatus: AdminUserStatus
    ) async throws
}

public struct UpdateAdminUserAccessUseCase: UpdateAdminUserAccessUseCaseProtocol {
    private let repository: AdminUsersRepositoryProtocol

    public init(repository: AdminUsersRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        userId: String,
        currentRole: AdminUserRole, currentStatus: AdminUserStatus,
        newRole: AdminUserRole, newStatus: AdminUserStatus
    ) async throws {
        guard let change = AdminUserAccessChange.diff(
            currentRole: currentRole, currentStatus: currentStatus,
            newRole: newRole, newStatus: newStatus
        ) else {
            throw AdminUsersError.noAccessChanges
        }
        try await repository.updateAccess(userId: userId, change: change)
    }
}
