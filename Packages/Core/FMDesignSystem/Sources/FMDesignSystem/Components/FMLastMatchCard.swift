import SwiftUI

/// Result of a played match from the current player's point of view.
public enum FMMatchOutcome {
    case win, loss, draw
}

/// Last played match: both teams around the score, with the venue and a relative
/// date underneath. The whole card is the tap target.
public struct FMLastMatchCard: View {
    let teamAName: String
    let teamAColorHex: String?
    let teamBName: String
    let teamBColorHex: String?
    let scoreA: Int
    let scoreB: Int
    let outcome: FMMatchOutcome
    let outcomeLabel: String
    let completedLabel: String
    let fieldName: String
    let dateLabel: String
    let isLoading: Bool
    let onTap: () -> Void

    public init(
        teamAName: String,
        teamAColorHex: String?,
        teamBName: String,
        teamBColorHex: String?,
        scoreA: Int,
        scoreB: Int,
        outcome: FMMatchOutcome,
        outcomeLabel: String,
        completedLabel: String,
        fieldName: String,
        dateLabel: String,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.teamAName = teamAName
        self.teamAColorHex = teamAColorHex
        self.teamBName = teamBName
        self.teamBColorHex = teamBColorHex
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.outcome = outcome
        self.outcomeLabel = outcomeLabel
        self.completedLabel = completedLabel
        self.fieldName = fieldName
        self.dateLabel = dateLabel
        self.isLoading = isLoading
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    teamColumn(name: teamAName, colorHex: teamAColorHex)

                    VStack(spacing: 4) {
                        outcomePill
                        Text("\(scoreA) - \(scoreB)")
                            .font(FMTypography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(FMColors.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(completedLabel)
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)

                    teamColumn(name: teamBName, colorHex: teamBColorHex)
                }

                Divider()

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                        Text(fieldName.isEmpty ? "-" : fieldName)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isLoading {
                        ProgressView().tint(FMColors.primary)
                    } else {
                        Text(dateLabel)
                            .lineLimit(1)
                    }
                }
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Pieces

    private func teamColumn(name: String, colorHex: String?) -> some View {
        VStack(spacing: 8) {
            FMTeamJersey(color: colorHex.flatMap { Color(fmHex: $0) } ?? FMColors.surfaceVariant, size: 42)
            Text(name)
                .font(FMTypography.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(FMColors.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    private var outcomePill: some View {
        Text(outcomeLabel)
            .font(FMTypography.labelSmall)
            .foregroundColor(outcomeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(outcomeColor.opacity(outcome == .win ? 0.16 : 0.14)))
    }

    private var outcomeColor: Color {
        switch outcome {
        case .win: return Color(fmHex: "#16864B") ?? .green
        case .loss: return FMColors.error
        case .draw: return FMColors.tertiary
        }
    }
}

// MARK: - Previews

#Preview("Last match – all outcomes") {
    ScrollView {
        VStack(spacing: 16) {
            FMLastMatchCard(
                teamAName: "Les Bleus", teamAColorHex: "#0066FF",
                teamBName: "Los Blancos", teamBColorHex: "#FFFFFF",
                scoreA: 9, scoreB: 13, outcome: .win, outcomeLabel: "Victoria",
                completedLabel: "Finalizado", fieldName: "La Jaula",
                dateLabel: "Hace 60 días a las 00:00", onTap: {}
            )
            FMLastMatchCard(
                teamAName: "Red Devils", teamAColorHex: "#EF1B23",
                teamBName: "Los Verdes", teamBColorHex: "#1E8A4C",
                scoreA: 7, scoreB: 4, outcome: .loss, outcomeLabel: "Derrota",
                completedLabel: "Finalizado", fieldName: "Cancha Roma",
                dateLabel: "Ayer a las 19:00", onTap: {}
            )
            FMLastMatchCard(
                teamAName: "All Blacks", teamAColorHex: "#000000",
                teamBName: "Equipo Sur", teamBColorHex: "#F28C28",
                scoreA: 8, scoreB: 8, outcome: .draw, outcomeLabel: "Empate",
                completedLabel: "Finalizado", fieldName: "Club Central",
                dateLabel: "Hoy a las 19:00", onTap: {}
            )
            // Historical match: no team identities → fallback names + neutral jerseys.
            FMLastMatchCard(
                teamAName: "Equipo A", teamAColorHex: nil,
                teamBName: "Equipo B", teamBColorHex: nil,
                scoreA: 5, scoreB: 3, outcome: .win, outcomeLabel: "Victoria",
                completedLabel: "Finalizado", fieldName: "La Jaula",
                dateLabel: "Hace 120 días a las 00:00", onTap: {}
            )
        }
        .padding(24)
    }
    .background(FMColors.background)
}
