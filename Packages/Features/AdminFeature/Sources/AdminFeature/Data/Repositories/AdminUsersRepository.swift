import Foundation

struct AdminUsersRepository: AdminUsersRepositoryProtocol {
    private let service: AdminUsersServiceProtocol

    init(service: AdminUsersServiceProtocol) {
        self.service = service
    }

    func fetchUsers(role: AdminUserRole, page: Int) async throws -> AdminPage<AdminUserSummary> {
        try await service.fetchUsers(roles: [role], page: page, pageSize: AdminUsersPaging.usersPageSize)
    }

    func fetchUserDetail(userId: String) async throws -> AdminUserDetail {
        try await service.fetchUserDetail(userId: userId)
    }

    func fetchPaymentHistory(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment> {
        try await service.fetchPaymentHistory(userId: userId, page: page)
    }

    func updateAccess(userId: String, change: AdminUserAccessChange) async throws {
        try await service.updateAccess(userId: userId, change: change)
    }
}
