import SwiftUI
import FMDesignSystem

/// Maps the domain `LastMatch` onto the design-system card. The visuals (and their
/// previews) live in `FMLastMatchCard`, which has no Firebase dependency.
struct LastMatchCard: View {
    let match: LastMatch
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        FMLastMatchCard(
            teamAName: match.teamAName,
            teamAColorHex: match.teamA?.colorHex,
            teamBName: match.teamBName,
            teamBColorHex: match.teamB?.colorHex,
            scoreA: match.teamAScore,
            scoreB: match.teamBScore,
            outcome: outcome,
            outcomeLabel: match.outcomeLabel,
            completedLabel: L10n.LastMatch.completed,
            fieldName: match.fieldName,
            dateLabel: match.relativeDateLabel(),
            isLoading: isLoading,
            onTap: onTap
        )
    }

    private var outcome: FMMatchOutcome {
        switch match.outcome {
        case .win: return .win
        case .loss: return .loss
        case .draw: return .draw
        }
    }
}
