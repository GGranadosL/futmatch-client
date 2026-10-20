import Foundation

// MARK: - Last Match Outcome

enum LastMatchOutcome: String {
    case win = "WIN"
    case loss = "LOSS"
    case draw = "DRAW"
}

// MARK: - Last Match

struct LastMatch {
    let matchId: String
    let fieldName: String
    let playedAt: Date
    let outcome: LastMatchOutcome
    let teamAScore: Int
    let teamBScore: Int
    /// `nil` for matches created before team identities existed.
    let teamA: MatchTeamVisual?
    let teamB: MatchTeamVisual?

    init(
        matchId: String,
        fieldName: String,
        playedAt: Date,
        outcome: LastMatchOutcome,
        teamAScore: Int,
        teamBScore: Int,
        teamA: MatchTeamVisual? = nil,
        teamB: MatchTeamVisual? = nil
    ) {
        self.matchId = matchId
        self.fieldName = fieldName
        self.playedAt = playedAt
        self.outcome = outcome
        self.teamAScore = teamAScore
        self.teamBScore = teamBScore
        self.teamA = teamA
        self.teamB = teamB
    }

    var outcomeLabel: String {
        switch outcome {
        case .win: return L10n.LastMatch.win
        case .loss: return L10n.LastMatch.loss
        case .draw: return L10n.LastMatch.draw
        }
    }

    var teamAName: String { teamA?.name.nonEmpty ?? L10n.Matches.teamA }
    var teamBName: String { teamB?.name.nonEmpty ?? L10n.Matches.teamB }

    /// "Hoy a las 19:00", "Ayer a las 19:00" or "Hace N días a las 19:00".
    func relativeDateLabel(now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let time = timeFormatter.string(from: playedAt)

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: playedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        switch days {
        case ...0: return L10n.LastMatch.todayAt(time)
        case 1: return L10n.LastMatch.yesterdayAt(time)
        default: return L10n.LastMatch.daysAgoAt(days, time)
        }
    }
}
