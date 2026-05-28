import Foundation

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

    private let notificationService: NotificationServiceProtocol
    private let fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol

    private static let seenIdsKey = "notifications.seenIds"
    /// IDs of notifications the user has already seen. Persisted across launches.
    /// The badge counts notifications whose ID is NOT in this set (i.e. new ones).
    private var seenIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.seenIdsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.seenIdsKey) }
    }

    init(
        notificationService: NotificationServiceProtocol,
        fetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol
    ) {
        self.notificationService = notificationService
        self.fetchMatchDetailUseCase = fetchMatchDetailUseCase
    }

    // MARK: - Load

    /// Lightweight background fetch — only updates `unreadCount`, used by HomeView badge.
    /// Counts notifications the user hasn't seen yet (ID not in `seenIds`).
    func loadUnreadCount() async {
        do {
            let items = try await notificationService.fetchNotifications()
            let seen = seenIds
            unreadCount = items.filter { !seen.contains($0.id) }.count
        } catch { /* silent — badge stays at previous value */ }
    }

    func load() async {
        state = .loading
        do {
            let items = try await notificationService.fetchNotifications()
            let sections = groupByDate(items)
            state = sections.isEmpty ? .empty : .loaded(sections)
            // The user is now viewing the list — mark everything currently shown as seen.
            markSeen(items)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Immediately clears the badge when the user opens the screen.
    /// The persisted seen-IDs are updated by `load()` once the items arrive.
    func markAsSeen() {
        unreadCount = 0
    }

    /// Records the given notifications as seen. Replaces the stored set with the
    /// current IDs so the badge only counts genuinely new notifications next time
    /// (and so deleted notifications don't linger in the set).
    private func markSeen(_ items: [NotificationItem]) {
        seenIds = Set(items.map { $0.id })
        unreadCount = 0
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
            state = updated.isEmpty ? .empty : .loaded(updated)
        }
        // Fire-and-forget — if it fails the item is already gone visually (matches common app patterns)
        try? await notificationService.deleteNotification(id: id)
    }

    // MARK: - Tap → Navigate to MatchDetail

    func handleTap(_ item: NotificationItem) async {
        guard let matchId = item.metadata?.matchId else { return }
        isNavigating = true
        defer { isNavigating = false }
        do {
            let match = try await fetchMatchDetailUseCase.execute(matchId: matchId)
            pendingNavigation = match
        } catch {
            #if DEBUG
            print("❌ NotificationsViewModel: could not fetch match \(matchId) — \(error)")
            #endif
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
