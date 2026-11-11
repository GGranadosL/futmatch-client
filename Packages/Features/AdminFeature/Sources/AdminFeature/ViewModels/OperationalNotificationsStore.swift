import Foundation
import SwiftUI

/// Unread counters of the ADMIN and ORGANIZER inboxes for the signed-in user.
///
/// One instance per session (it is recreated with the home container on logout, so
/// one account's counters never show for another). Loads for the same inbox are
/// shared, and a response that started before a newer value was set is dropped.
@MainActor
public final class OperationalNotificationsStore: ObservableObject {
    @Published public private(set) var unreadCounts: [OperationalInbox: Int] = [:]

    private let fetchCountUseCase: FetchOperationalUnreadCountUseCaseProtocol
    private var inFlight: [OperationalInbox: Task<Void, Never>] = [:]
    private var generation: [OperationalInbox: Int] = [:]
    private var observer: NSObjectProtocol?

    public init(
        fetchCountUseCase: FetchOperationalUnreadCountUseCaseProtocol,
        notificationCenter: NotificationCenter = .default
    ) {
        self.fetchCountUseCase = fetchCountUseCase
        observer = notificationCenter.addObserver(
            forName: .operationalNotificationPushReceived, object: nil, queue: .main
        ) { [weak self] note in
            guard let inbox = OperationalInbox(raw: note.userInfo?["inbox"] as? String) else { return }
            Task { @MainActor [weak self] in self?.registerIncoming(inbox) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// `nil` until the server has answered once.
    public func count(for inbox: OperationalInbox) -> Int? {
        unreadCounts[inbox]
    }

    public func hasUnread(_ inbox: OperationalInbox) -> Bool {
        (unreadCounts[inbox] ?? 0) > 0
    }

    /// Reads the count from the server. Concurrent calls for the same inbox share one
    /// request; `afterCurrent` waits for a running one and then asks again (its answer
    /// may predate the event that triggered this call).
    public func refresh(_ inbox: OperationalInbox, afterCurrent: Bool = false) async {
        if let running = inFlight[inbox] {
            await running.value
            guard afterCurrent else { return }
            if let next = inFlight[inbox] {
                await next.value
                return
            }
        }
        let startedAt = generation[inbox, default: 0]
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlight[inbox] = nil }
            guard let count = try? await self.fetchCountUseCase.execute(inbox: inbox) else { return }
            // A newer value (read-all, logout) landed while this was in flight.
            guard self.generation[inbox, default: 0] == startedAt else { return }
            self.unreadCounts[inbox] = max(0, count)
        }
        inFlight[inbox] = task
        await task.value
    }

    /// Stores a count the hub already reconciled with the server.
    public func set(_ count: Int, for inbox: OperationalInbox) {
        generation[inbox, default: 0] += 1
        unreadCounts[inbox] = max(0, count)
    }

    /// A push for this inbox arrived: show it right away, then confirm with the server.
    public func registerIncoming(_ inbox: OperationalInbox) {
        generation[inbox, default: 0] += 1
        unreadCounts[inbox] = (unreadCounts[inbox] ?? 0) + 1
        Task { await refresh(inbox, afterCurrent: true) }
    }

    public func reset() {
        inFlight.values.forEach { $0.cancel() }
        inFlight = [:]
        for inbox in OperationalInbox.allCases { generation[inbox, default: 0] += 1 }
        unreadCounts = [:]
    }
}

// MARK: - Environment

private struct OperationalNotificationsStoreKey: EnvironmentKey {
    static let defaultValue: OperationalNotificationsStore? = nil
}

extension EnvironmentValues {
    /// Optional so admin screens still render (without bells) where no store was injected.
    public var operationalNotificationsStore: OperationalNotificationsStore? {
        get { self[OperationalNotificationsStoreKey.self] }
        set { self[OperationalNotificationsStoreKey.self] = newValue }
    }
}
