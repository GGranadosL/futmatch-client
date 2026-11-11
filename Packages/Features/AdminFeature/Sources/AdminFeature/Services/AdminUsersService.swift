import Foundation
import NetworkFramework

// MARK: - Protocol

protocol AdminUsersServiceProtocol {
    func fetchUsers(roles: [AdminUserRole], page: Int, pageSize: Int) async throws -> AdminPage<AdminUserSummary>
    func fetchUserDetail(userId: String) async throws -> AdminUserDetail
    func fetchPaymentHistory(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment>
    func updateAccess(userId: String, change: AdminUserAccessChange) async throws
}

// MARK: - Implementation

struct AdminUsersService: AdminUsersServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchUsers(roles: [AdminUserRole], page: Int, pageSize: Int) async throws -> AdminPage<AdminUserSummary> {
        let response: AdminUsersPageResponseDTO = try await apiClient.request(
            endpoint: AdminUsersEndpoint.list(roles: roles, page: page, pageSize: pageSize)
        )
        let data = response.data
        return AdminPage(
            items: data.items.map { $0.toDomain() },
            page: data.page ?? page,
            pageSize: data.pageSize ?? pageSize,
            total: data.total ?? data.items.count
        )
    }

    func fetchUserDetail(userId: String) async throws -> AdminUserDetail {
        let response: AdminUserDetailResponseDTO = try await apiClient.request(
            endpoint: AdminUsersEndpoint.detail(userId: userId)
        )
        return response.data.toDomain()
    }

    func fetchPaymentHistory(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment> {
        let response: AdminUserPaymentsResponseDTO = try await apiClient.request(
            endpoint: AdminUsersEndpoint.paymentHistory(userId: userId, page: page)
        )
        let data = response.data
        return AdminPage(
            items: data.items.map { $0.toDomain() },
            page: data.page ?? page,
            pageSize: data.pageSize ?? AdminUsersPaging.paymentsPageSize,
            total: data.total ?? data.items.count
        )
    }

    func updateAccess(userId: String, change: AdminUserAccessChange) async throws {
        let _: AdminUserAccessResponseDTO = try await apiClient.request(
            endpoint: AdminUsersEndpoint.updateAccess(userId: userId),
            body: UpdateAdminUserAccessRequestDTO(change: change)
        )
    }
}

enum AdminUsersPaging {
    static let usersPageSize = 20
    /// Fixed by the backend.
    static let paymentsPageSize = 5
}
