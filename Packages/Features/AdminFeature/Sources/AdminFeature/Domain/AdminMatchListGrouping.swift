import Foundation

// MARK: - AdminMatchListTab

/// Tabs shared by the admin and organizer match lists.
enum AdminMatchListTab: CaseIterable {
    case upcoming, finished, canceled

    var label: String {
        switch self {
        case .upcoming:  return L10n.AdminMatches.tabUpcoming
        case .finished:  return L10n.AdminMatches.tabFinished
        case .canceled:  return L10n.AdminMatches.tabCanceled
        }
    }

    var emptyMessage: String {
        switch self {
        case .upcoming:  return L10n.AdminMatches.emptyUpcoming
        case .finished:  return L10n.AdminMatches.emptyFinished
        case .canceled:  return L10n.AdminMatches.emptyCanceled
        }
    }

    /// Matches that belong to this tab.
    func filter(_ matches: [AdminMatch]) -> [AdminMatch] {
        switch self {
        case .upcoming:  return matches.filter { $0.status == .scheduled || $0.status == .inProgress }
        case .finished:  return matches.filter { $0.status == .completed }
        case .canceled:  return matches.filter { $0.status == .canceled }
        }
    }
}

// MARK: - AdminMatchDaySection

/// One calendar day of matches. `id` is the day itself so SwiftUI keeps the
/// section — and the cards inside it — alive across refreshes; an unstable id
/// would rebuild every card and reset its downloaded field image (flicker).
struct AdminMatchDaySection: Identifiable, Equatable {
    let id: Date
    let title: String
    let matches: [AdminMatch]
}

// MARK: - AdminMatchListGrouping

/// Groups a tab's matches into day sections, today first:
/// - `.upcoming` / `.canceled`: today, then future days ascending; any
///   stale past-dated entries go last (most recent first).
/// - `.finished`: most recent day first.
enum AdminMatchListGrouping {

    static func sections(
        _ matches: [AdminMatch],
        tab: AdminMatchListTab,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [AdminMatchDaySection] {
        let today = calendar.startOfDay(for: now)

        var byDay: [Date: [AdminMatch]] = [:]
        for match in matches {
            byDay[calendar.startOfDay(for: match.startDate), default: []].append(match)
        }

        let orderedDays: [Date]
        switch tab {
        case .upcoming, .canceled:
            let currentAndFuture = byDay.keys.filter { $0 >= today }.sorted(by: <)
            let past             = byDay.keys.filter { $0 <  today }.sorted(by: >)
            orderedDays = currentAndFuture + past
        case .finished:
            orderedDays = byDay.keys.sorted(by: >)
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")

        return orderedDays.map { day in
            let chronological = tab != .finished && day >= today
            let dayMatches = (byDay[day] ?? []).sorted {
                chronological ? $0.startDate < $1.startDate : $0.startDate > $1.startDate
            }
            return AdminMatchDaySection(
                id: day,
                title: title(for: day, today: today, calendar: calendar, formatter: formatter),
                matches: dayMatches
            )
        }
    }

    private static func title(
        for day: Date,
        today: Date,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> String {
        if calendar.isDate(day, inSameDayAs: today) {
            return L10n.AdminMatches.sectionToday
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(day, inSameDayAs: tomorrow) {
            return L10n.AdminMatches.sectionTomorrow
        }
        let label = formatter.string(from: day)
        return label.prefix(1).localizedUppercase + label.dropFirst()
    }
}
