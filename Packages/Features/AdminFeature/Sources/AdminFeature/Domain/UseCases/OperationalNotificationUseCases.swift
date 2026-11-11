import Foundation

// MARK: - Unread count

public protocol FetchOperationalUnreadCountUseCaseProtocol {
    func execute(inbox: OperationalInbox) async throws -> Int
}

public struct FetchOperationalUnreadCountUseCase: FetchOperationalUnreadCountUseCaseProtocol {
    private let repository: OperationalNotificationRepositoryProtocol

    public init(repository: OperationalNotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(inbox: OperationalInbox) async throws -> Int {
        try await repository.fetchUnreadCount(inbox: inbox)
    }
}

// MARK: - Open inbox (read policy)

public struct OperationalInboxSnapshot: Equatable {
    public let items: [OperationalNotification]
    /// Server count re-read after a successful read-all; `nil` when no read-all ran
    /// or it failed (the caller keeps its counter).
    public let reconciledUnreadCount: Int?
    /// Set when read-all failed: the badge stays and the user can retry.
    public let markReadFailed: Bool
    public let markReadErrorMessage: String?
}

public protocol OpenOperationalInboxUseCaseProtocol {
    /// - Parameter knownUnreadCount: the counter the client already has, `nil` if unknown.
    func execute(inbox: OperationalInbox, knownUnreadCount: Int?) async throws -> OperationalInboxSnapshot
}

/// Opening or refreshing a hub:
/// 1. Known count > 0 → mark read before loading.
/// 2. Known count 0 (or unknown) → no read-all, unless the history turns out to have
///    unread items (stale counter): then mark read in this same inbox.
/// 3. After a successful read-all the count is fetched again, because pushes may have
///    arrived meanwhile and `markedAsReadCount` isn't the current count.
public struct OpenOperationalInboxUseCase: OpenOperationalInboxUseCaseProtocol {
    private let repository: OperationalNotificationRepositoryProtocol

    public init(repository: OperationalNotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(inbox: OperationalInbox, knownUnreadCount: Int?) async throws -> OperationalInboxSnapshot {
        var didMark = false
        var markError: Error?

        if let known = knownUnreadCount, known > 0 {
            do {
                try await repository.markAllRead(inbox: inbox)
                didMark = true
            } catch {
                markError = error
            }
        }

        let items: [OperationalNotification]
        do {
            items = try await repository.fetchNotifications(inbox: inbox)
        } catch {
            if didMark { _ = try? await repository.fetchUnreadCount(inbox: inbox) }
            throw error
        }

        if !didMark, markError == nil, items.contains(where: { !$0.isRead }) {
            do {
                try await repository.markAllRead(inbox: inbox)
                didMark = true
            } catch {
                markError = error
            }
        }

        var reconciled: Int?
        if didMark {
            reconciled = try? await repository.fetchUnreadCount(inbox: inbox)
        }

        return OperationalInboxSnapshot(
            items: items,
            reconciledUnreadCount: reconciled,
            markReadFailed: markError != nil,
            markReadErrorMessage: markError?.localizedDescription
        )
    }
}

// MARK: - Delete

public protocol DeleteOperationalNotificationUseCaseProtocol {
    func execute(id: String, inbox: OperationalInbox) async throws
}

public struct DeleteOperationalNotificationUseCase: DeleteOperationalNotificationUseCaseProtocol {
    private let repository: OperationalNotificationRepositoryProtocol

    public init(repository: OperationalNotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String, inbox: OperationalInbox) async throws {
        try await repository.delete(id: id, inbox: inbox)
    }
}

// MARK: - Match for a notification

public protocol FindOperationalMatchUseCaseProtocol {
    /// The match as the inbox's role sees it; `nil` when it isn't in that list anymore
    /// (deleted, or no longer supervised). The payload is never taken as authorization.
    func execute(matchId: String, inbox: OperationalInbox) async throws -> AdminMatch?
}

public struct FindOperationalMatchUseCase: FindOperationalMatchUseCaseProtocol {
    private let adminMatches: FetchMatchesListUseCaseProtocol
    private let organizerMatches: FetchMatchesListUseCaseProtocol

    public init(adminMatches: FetchMatchesListUseCaseProtocol, organizerMatches: FetchMatchesListUseCaseProtocol) {
        self.adminMatches = adminMatches
        self.organizerMatches = organizerMatches
    }

    public func execute(matchId: String, inbox: OperationalInbox) async throws -> AdminMatch? {
        let source = inbox == .admin ? adminMatches : organizerMatches
        return try await source.execute().first { $0.id == matchId }
    }
}
