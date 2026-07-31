import Foundation

// MARK: - Protocol

protocol FetchNotificationsUseCaseProtocol {
    /// Returns `nil` when the call is skipped (not stale enough and not forced) —
    /// the caller should keep showing whatever it already has. Returns the fresh
    /// list otherwise (possibly empty).
    func execute(forceRefresh: Bool) async throws -> [NotificationItem]?
}

// MARK: - Implementation

struct FetchNotificationsUseCase: FetchNotificationsUseCaseProtocol {
    private let notificationService: NotificationServiceProtocol
    private let timestampStore: NotificationFetchTimestampStoreProtocol
    private let safetyNetInterval: TimeInterval

    init(
        notificationService: NotificationServiceProtocol,
        timestampStore: NotificationFetchTimestampStoreProtocol,
        safetyNetInterval: TimeInterval = 300
    ) {
        self.notificationService = notificationService
        self.timestampStore = timestampStore
        self.safetyNetInterval = safetyNetInterval
    }

    func execute(forceRefresh: Bool) async throws -> [NotificationItem]? {
        if !forceRefresh,
           let last = timestampStore.lastFetchedAt,
           Date().timeIntervalSince(last) < safetyNetInterval {
            return nil
        }
        let items = try await notificationService.fetchNotifications()
        timestampStore.setLastFetchedAt(Date())
        return items
    }
}
