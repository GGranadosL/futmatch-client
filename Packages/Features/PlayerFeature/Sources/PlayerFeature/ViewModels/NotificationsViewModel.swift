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
    /// Number of notifications where `isRead == false`.
    /// Used by HomeView to show the bell badge.
    @Published private(set) var unreadCount: Int = 0
    /// Populated after a tap triggers a successful match-detail fetch.
    @Published private(set) var pendingNavigation: MatchItem? = nil
    @Published private(set) var isNavigating: Bool = false

    /// Number of unread notifications the user has already seen.
    /// Persisted across foreground/background cycles so the badge only bumps
    /// when the server returns MORE unread items than what the user last saw.
    private static let seenCountKey = "notifications.seenUnreadCount"
    private var lastSeenCount: Int {
        get { UserDefaults.standard.integer(forKey: Self.seenCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.seenCountKey) }
    }

    private let notificationService: NotificationServiceProtocol
    private let fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol
    private let fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        notificationService: NotificationServiceProtocol,
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    ) {
        self.notificationService = notificationService
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.fetchMatchDetailUseCase = fetchMatchDetailUseCase
        observePushNotifications()
    }

    // MARK: - Load

    /// Lightweight background fetch — only updates `unreadCount`, used by HomeView badge.
    /// Only shows a badge when the server returns MORE unread items than the user last saw,
    /// so visiting the notifications screen permanently suppresses the old count even
    /// after the app returns from background.
    func loadUnreadCount(forceRefresh: Bool = false) async {
        do {
            guard let items = try await fetchNotificationsUseCase.execute(forceRefresh: forceRefresh) else {
                return // Skipped — not stale enough and not forced, keep current badge.
            }
            let serverCount = items.filter { !$0.isRead }.count
            // Only surface a badge for items beyond what the user already acknowledged.
            unreadCount = max(0, serverCount - lastSeenCount)
        } catch {
            guard !(error is CancellationError) else { return }
            /* silent — badge stays at previous value */
        }
    }

    func load(forceRefresh: Bool = false) async {
        let hasData: Bool
        switch state {
        case .loaded, .empty: hasData = true
        default: hasData = false
        }
        if !hasData { state = .loading }
        do {
            // Force through the use case if there's nothing displayable yet —
            // otherwise a recent badge check could throttle this and leave the
            // screen stuck showing the loading spinner forever.
            guard let items = try await fetchNotificationsUseCase.execute(forceRefresh: forceRefresh || !hasData) else {
                return // Skipped — already showing fresh-enough data.
            }
            let sections = groupByDate(items)
            state = sections.isEmpty ? .empty : .loaded(sections)
            // Persist the current server count so future polls don't re-trigger the badge.
            let serverCount = items.filter { !$0.isRead }.count
            lastSeenCount = serverCount
            unreadCount = 0
        } catch {
            guard !(error is CancellationError) else { return }
            // Only surface the error full-screen if we have nothing else to show;
            // otherwise keep the stale-but-valid list visible.
            if !hasData { state = .failed(error.localizedDescription) }
        }
    }

    // MARK: - Push-Driven Refresh

    /// Any non-`matches_updated` remote push is treated as a signal that a new
    /// in-app notification was created server-side (no distinguishing `type` is
    /// sent yet), so force a real fetch to refresh the badge immediately.
    private func observePushNotifications() {
        NotificationCenter.default.publisher(for: .inAppNotificationsPushReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadUnreadCount(forceRefresh: true) }
            }
            .store(in: &cancellables)
    }

    /// Clears the badge and persists the current server count so background polls
    /// don't restore it unless NEW unread notifications arrive.
    func markAsSeen() {
        // Snapshot current unreadCount as the new baseline before load() runs.
        // load() will overwrite lastSeenCount with the precise server value.
        unreadCount = 0
    }


    /// Resets all notification state on logout so the next user starts clean.
    func clearOnLogout() {
        lastSeenCount = 0
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
        // Fire-and-forget — if it fails the item is already gone visually (matches common app patterns)
        try? await notificationService.deleteNotification(id: id)
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
