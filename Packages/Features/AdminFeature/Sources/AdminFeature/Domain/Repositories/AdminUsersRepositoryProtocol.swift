import Foundation

public protocol AdminUsersRepositoryProtocol {
    func fetchUsers(role: AdminUserRole, page: Int) async throws -> AdminPage<AdminUserSummary>
    func fetchUserDetail(userId: String) async throws -> AdminUserDetail
    func fetchPaymentHistory(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment>
    func updateAccess(userId: String, change: AdminUserAccessChange) async throws
}
