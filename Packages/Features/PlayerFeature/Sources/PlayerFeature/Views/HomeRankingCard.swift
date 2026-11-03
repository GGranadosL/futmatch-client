import SwiftUI
import FMDesignSystem

/// Home's monthly Victories summary. Tappable whenever there is a usable summary (even
/// without participation); with none it reads "unavailable" and doesn't navigate.
struct HomeRankingCard: View {
    let ranking: HomeRanking?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                header
                if let ranking {
                    if ranking.isParticipating {
                        rankedContent(ranking)
                    } else {
                        notParticipatingContent
                    }
                    Text(L10n.HomeRanking.viewClassification)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)
                } else {
                    unavailableContent
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ranking == nil ? FMColors.surfaceContainerHigh : FMColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
            .opacity(ranking == nil ? 0.7 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(ranking == nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(ranking == nil ? [] : .isButton)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 16))
                .foregroundColor(FMColors.primary)
                .accessibilityHidden(true)
            Text(L10n.HomeRanking.cardTitle)
                .font(FMTypography.titleSmall)
                .foregroundColor(FMColors.onSurface)
            Spacer(minLength: 8)
            if let ranking {
                Text(RankingFormatting.month(ranking.season))
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
    }

    @ViewBuilder
    private func rankedContent(_ ranking: HomeRanking) -> some View {
        HStack(spacing: 12) {
            if let position = ranking.position {
                Text(L10n.HomeRanking.position(position))
                    .font(.interBold(size: 32))
                    .foregroundColor(FMColors.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.HomeRanking.yourPlace)
                    .font(FMTypography.titleSmall)
                    .foregroundColor(FMColors.onSurface)
                Text(ranking.community.isGlobal ? L10n.HomeRanking.global : ranking.community.name)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }

        Text(L10n.HomeRanking.statistics(victories: ranking.victories, matchesPlayed: ranking.matchesPlayed))
            .font(FMTypography.bodyMedium)
            .foregroundColor(FMColors.onSurfaceVariant)

        if let difference = ranking.victoriesToTarget, let target = ranking.nextTarget {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
                Text(L10n.HomeRanking.nextTarget(victories: difference, position: target.position))
                    .font(FMTypography.bodySmall)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(FMColors.onPrimaryContainer)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(FMColors.primaryContainer))
        }
    }

    @ViewBuilder
    private var notParticipatingContent: some View {
        Text(L10n.HomeRanking.emptyTitle)
            .font(FMTypography.titleMedium)
            .foregroundColor(FMColors.onSurface)
        Text(L10n.HomeRanking.emptyDescription)
            .font(FMTypography.bodyMedium)
            .foregroundColor(FMColors.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var unavailableContent: some View {
        Text(L10n.HomeRanking.unavailable)
            .font(FMTypography.bodyMedium)
            .foregroundColor(FMColors.onSurfaceVariant)
        Text(L10n.HomeRanking.retryHint)
            .font(FMTypography.bodySmall)
            .foregroundColor(FMColors.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
    }
}
