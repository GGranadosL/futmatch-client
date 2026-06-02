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

    var outcomeLabel: String {
        switch outcome {
        case .win: return L10n.LastMatch.win
        case .loss: return L10n.LastMatch.loss
        case .draw: return L10n.LastMatch.draw
        }
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: playedAt, relativeTo: Date())
    }
}
