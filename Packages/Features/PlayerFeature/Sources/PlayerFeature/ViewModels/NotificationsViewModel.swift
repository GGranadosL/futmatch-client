import Foundation
import SwiftUI
import Combine

// MARK: - NotificationSection

struct NotificationSection: Identifiable {
    var id: String { title }
    let title: String
    let notifications: [NotificationItem]
}

// MARK: - NotificationsViewModel

@MainActor
final class NotificationsViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([NotificationSection])
        case empty
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// Unread notifications, mirrored from the local counter. Drives the bell badge.
    @Published private(set) var unreadCount: Int = 0
    /// Populated after a tap triggers a successful match-detail fetch.
    @Published private(set) var pendingNavigation: MatchItem? = nil
    @Published private(set) var isNavigating: Bool = false

    private let loadCachedUseCase: LoadCachedNotificationsUseCaseProtocol
    private let fetchUnreadCountUseCase: FetchUnreadNotificationCountUseCaseProtocol
    private let openInboxUseCase: OpenNotificationInboxUseCaseProtocol
    private let refreshInboxUseCase: RefreshNotificationInboxUseCaseProtocol
    private let deleteNotificationUseCase: DeleteNotificationUseCaseProtocol
    private let registerIncomingUseCase: RegisterIncomingNotificationUseCaseProtocol
    private let clearStateUseCase: ClearNotificationStateUseCaseProtocol
    private let fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedSessionUnreadCount = false

    init(
        loadCachedUseCase: LoadCachedNotificationsUseCaseProtocol,
        fetchUnreadCountUseCase: FetchUnreadNotificationCountUseCaseProtocol,
        openInboxUseCase: OpenNotificationInboxUseCaseProtocol,
        refreshInboxUseCase: RefreshNotificationInboxUseCaseProtocol,
        deleteNotificationUseCase: DeleteNotificationUseCaseProtocol,
        registerIncomingUseCase: RegisterIncomingNotificationUseCaseProtocol,
        clearStateUseCase: ClearNotificationStateUseCaseProtocol,
        fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    ) {
        self.loadCachedUseCase = loadCachedUseCase
        self.fetchUnreadCountUseCase = fetchUnreadCountUseCase
        self.openInboxUseCase = openInboxUseCase
        self.refreshInboxUseCase = refreshInboxUseCase
        self.deleteNotificationUseCase = deleteNotificationUseCase
        self.registerIncomingUseCase = registerIncomingUseCase
        self.clearStateUseCase = clearStateUseCase
        self.fetchMatchDetailUseCase = fetchMatchDetailUseCase
        // Show the last known badge right away, before any request.
        unreadCount = loadCachedUseCase.execute().unreadCount
        observePushNotifications()
    }

    // MARK: - Session Badge

    /// Pulls the server's unread count once per authenticated session. Coming back to
    /// the foreground or switching tabs does not ask again: pushes keep the counter
    /// current, and pull-to-refresh reconciles it.
    func loadUnreadCountForSession() async {
        guard !hasLoadedSessionUnreadCount else { return }
        do {
            unreadCount = try await fetchUnreadCountUseCase.execute()
            hasLoadedSessionUnreadCount = true
        } catch {
            guard !error.isCancellation else { return }
            /* silent — badge stays at the last known value; the next session retries */
        }
    }

    // MARK: - Inbox

    /// Called when the notifications screen opens.
    func open() async {
        let cached = loadCachedUseCase.execute()
        let hasCachedItems = !cached.items.isEmpty
        if hasCachedItems { apply(cached.items) } else { state = .loading }

        do {
            let inbox = try await openInboxUseCase.execute()
            apply(inbox)
        } catch {
            guard !error.isCancellation else { return }
            // Keep a stale-but-valid list on screen; only fail full-screen when there is none.
            if !hasCachedItems { state = .failed(error.localizedDescription) }
        }
    }

    func refresh() async {
        do {
            apply(try await refreshInboxUseCase.execute())
        } catch {
            guard !error.isCancellation else { return }
            if case .loaded = state { return }
            if case .empty = state { return }
            state = .failed(error.localizedDescription)
        }
    }

    /// Retry from the full-screen error.
    func retry() async {
        state = .loading
        await open()
    }

    private func apply(_ inbox: NotificationInbox) {
        unreadCount = inbox.unreadCount
        apply(inbox.items)
    }

    private func apply(_ items: [NotificationItem]) {
        let sections = groupByDate(items)
        state = sections.isEmpty ? .empty : .loaded(sections)
    }

    // MARK: - Push-Driven Badge

    /// A visible push for a user notification arrived: bump the local counter.
    /// Data-only pushes such as `matches_updated` never post this notification.
    private func observePushNotifications() {
        NotificationCenter.default.publisher(for: .inAppNotificationsPushReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.unreadCount = self.registerIncomingUseCase.execute()
            }
            .store(in: &cancellables)
    }

    /// Resets all notification state on logout so the next user starts clean.
    func clearOnLogout() {
        clearStateUseCase.execute()
        hasLoadedSessionUnreadCount = false
        unreadCount = 0
        state = .idle
    }

    // MARK: - Delete (optimistic)

    func delete(id: String) async {
        // Remove immediately from UI
        if case .loaded(let sections) = state {
            let updated = sections.compactMap { section -> NotificationSection? in
                let remaining = section.notifications.filter { $0.id != id }
                guard !remaining.isEmpty else { return nil }
                return NotificationSection(title: section.title, notifications: remaining)
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                state = updated.isEmpty ? .empty : .loaded(updated)
            }
        }
        do {
            try await deleteNotificationUseCase.execute(id: id)
        } catch {
            guard !error.isCancellation else { return }
            // Not deleted server-side, so it is still in the cache: bring it back.
            withAnimation(.easeInOut(duration: 0.3)) {
                apply(loadCachedUseCase.execute().items)
            }
        }
    }

    // MARK: - Tap → Navigate to MatchDetail

    func handleTap(_ item: NotificationItem) async {
        guard let matchId = item.metadata?.matchId else { return }
        isNavigating = true
        defer { isNavigating = false }
        if let match = try? await fetchMatchDetailUseCase.execute(matchId: matchId) {
            pendingNavigation = match
        }
    }

    /// Loads a match for a system-notification tap, which isn't tied to the inbox screen.
    func match(forId matchId: String) async -> MatchItem? {
        try? await fetchMatchDetailUseCase.execute(matchId: matchId)
    }

    /// Called by the View immediately after consuming `pendingNavigation`.
    func clearNavigation() {
        pendingNavigation = nil
    }

    // MARK: - Date Grouping

    private func groupByDate(_ items: [NotificationItem]) -> [NotificationSection] {
        let calendar = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekAgo   = calendar.date(byAdding: .day, value: -7, to: today)!

        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "es_MX")
        dayFmt.dateFormat = "EEEE"   // "lunes", "martes"…

        let fullFmt = DateFormatter()
        fullFmt.locale = Locale(identifier: "es_MX")
        fullFmt.dateFormat = "d 'de' MMMM yyyy"

        var grouped: [Date: [NotificationItem]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: item.createdAt)
            grouped[day, default: []].append(item)
        }

        return grouped.keys.sorted(by: >).compactMap { day in
            let dayItems = grouped[day]!.sorted { $0.createdAt > $1.createdAt }
            let title: String
            if calendar.isDate(day, inSameDayAs: today) {
                title = "Hoy"
            } else if calendar.isDate(day, inSameDayAs: yesterday) {
                title = "Ayer"
            } else if day >= weekAgo {
                title = dayFmt.string(from: day).capitalized
            } else {
                title = fullFmt.string(from: day).capitalized
            }
            return NotificationSection(title: title, notifications: dayItems)
        }
    }
}
