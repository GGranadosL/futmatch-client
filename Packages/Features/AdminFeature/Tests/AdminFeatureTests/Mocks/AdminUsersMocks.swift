import Foundation
@testable import AdminFeature

final class MockAdminUsersRepository: AdminUsersRepositoryProtocol {
    var usersResults: [Int: Result<AdminPage<AdminUserSummary>, Error>] = [:]
    var defaultUsersResult: Result<AdminPage<AdminUserSummary>, Error> = .success(AdminPage(items: [], page: 1, pageSize: 20, total: 0))
    var detailResult: Result<AdminUserDetail, Error> = .success(.stub())
    var paymentsResult: Result<AdminPage<AdminUserPayment>, Error> = .success(AdminPage(items: [], page: 1, pageSize: 5, total: 0))
    var updateResult: Result<Void, Error> = .success(())

    private(set) var fetchUsersCalls: [(role: AdminUserRole, page: Int)] = []
    private(set) var fetchDetailCallCount = 0
    private(set) var fetchPaymentsPages: [Int] = []
    private(set) var updateCalls: [(userId: String, change: AdminUserAccessChange)] = []

    func fetchUsers(role: AdminUserRole, page: Int) async throws -> AdminPage<AdminUserSummary> {
        fetchUsersCalls.append((role, page))
        return try (usersResults[page] ?? defaultUsersResult).get()
    }

    func fetchUserDetail(userId: String) async throws -> AdminUserDetail {
        fetchDetailCallCount += 1
        return try detailResult.get()
    }

    func fetchPaymentHistory(userId: String, page: Int) async throws -> AdminPage<AdminUserPayment> {
        fetchPaymentsPages.append(page)
        return try paymentsResult.get()
    }

    func updateAccess(userId: String, change: AdminUserAccessChange) async throws {
        updateCalls.append((userId, change))
        try updateResult.get()
    }
}

final class MockOperationalNotificationRepository: OperationalNotificationRepositoryProtocol {
    var notificationsResult: Result<[OperationalNotification], Error> = .success([])
    var countResults: [Result<Int, Error>] = []
    var markResult: Result<Void, Error> = .success(())
    var deleteResult: Result<Void, Error> = .success(())
    /// Suspends count requests until released (concurrency tests).
    var countGate: (() async -> Void)?

    private(set) var calls: [String] = []
    private(set) var countCallCount = 0

    func fetchNotifications(inbox: OperationalInbox) async throws -> [OperationalNotification] {
        calls.append("list:\(inbox.rawValue)")
        return try notificationsResult.get()
    }

    func fetchUnreadCount(inbox: OperationalInbox) async throws -> Int {
        calls.append("count:\(inbox.rawValue)")
        countCallCount += 1
        if let countGate { await countGate() }
        guard !countResults.isEmpty else { return 0 }
        return try countResults.removeFirst().get()
    }

    func markAllRead(inbox: OperationalInbox) async throws {
        calls.append("read:\(inbox.rawValue)")
        try markResult.get()
    }

    func delete(id: String, inbox: OperationalInbox) async throws {
        calls.append("delete:\(id):\(inbox.rawValue)")
        try deleteResult.get()
    }
}

struct StubMatchesList: FetchMatchesListUseCaseProtocol {
    var result: Result<[AdminMatch], Error>
    func execute() async throws -> [AdminMatch] { try result.get() }
}

extension AdminUserSummary {
    static func stub(
        id: String = "u-1",
        fullName: String = "Ana López",
        role: AdminUserRole = .player,
        status: AdminUserStatus = .active,
        createdAt: Date? = nil
    ) -> AdminUserSummary {
        AdminUserSummary(
            id: id, fullName: fullName, maskedEmail: "a***@example.com", countryCode: "MX",
            profilePicURL: nil, gender: "FEMALE", role: role, status: status,
            isEmailVerified: true, createdAt: createdAt
        )
    }
}

extension AdminUserDetail {
    static func stub(id: String = "u-1", role: AdminUserRole = .player, status: AdminUserStatus = .active) -> AdminUserDetail {
        AdminUserDetail(
            summary: .stub(id: id, role: role, status: status),
            maskedPhone: "***78", activeSessionCount: 1, failedLoginAttempts: 0, lockedUntil: nil,
            upcomingMatchesCount: 0, completedMatchesCount: nil, devices: []
        )
    }
}

extension OperationalNotification {
    static func stub(id: String = "n-1", isRead: Bool = true, matchId: String? = "m-1") -> OperationalNotification {
        OperationalNotification(
            id: id, title: "Revisa el partido programado", body: "…",
            type: OperationalNotification.paymentWindowWarningType,
            createdAt: Date(), isRead: isRead, matchId: matchId
        )
    }
}
