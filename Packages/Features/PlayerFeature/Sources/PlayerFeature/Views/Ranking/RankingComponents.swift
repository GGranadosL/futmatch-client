import SwiftUI
import FMDesignSystem

// MARK: - Header

struct RankingHeaderCard: View {
    let community: RankingCommunity?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Ranking.headline)
                    .font(.interBold(size: 22))
                    .foregroundColor(FMColors.onPrimaryContainer)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            Spacer(minLength: 8)
            Image(systemName: "soccerball")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(FMColors.primary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [FMColors.primaryContainer, FMColors.surface],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        )
    }

    private var subtitle: String {
        guard let community, !community.isGlobal else { return L10n.Ranking.globalSubtitle }
        return L10n.Ranking.communitySubtitle(community.name)
    }
}

// MARK: - Season picker

struct RankingSeasonPicker: View {
    let seasons: [RankingSeason]
    let selected: RankingSeason
    let onSelect: (RankingSeason) -> Void

    var body: some View {
        Menu {
            ForEach(Array(seasons.enumerated()), id: \.element) { index, season in
                Button {
                    onSelect(season)
                } label: {
                    if season == selected {
                        Label {
                            itemText(season, isCurrent: index == 0)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        itemText(season, isCurrent: index == 0)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 15))
                    .accessibilityHidden(true)
                Text(RankingFormatting.month(selected))
                    .font(FMTypography.labelLarge)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundColor(FMColors.onSurface)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMColors.outline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Ranking.selectSeason)
        .accessibilityValue(RankingFormatting.month(selected))
    }

    @ViewBuilder
    private func itemText(_ season: RankingSeason, isCurrent: Bool) -> some View {
        Text(RankingFormatting.month(season))
        if isCurrent {
            Text(L10n.Ranking.currentSeason)
        }
    }
}

// MARK: - Category toggle

struct RankingCategoryToggle: View {
    let selected: RankingCategory
    let onSelect: (RankingCategory) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RankingCategory.allCases, id: \.self) { category in
                let isSelected = category == selected
                Button {
                    onSelect(category)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category == .victories ? "trophy.fill" : "soccerball")
                            .font(.system(size: 14))
                            .accessibilityHidden(true)
                        Text(category == .victories ? L10n.Ranking.victoriesTab : L10n.Ranking.goalsTab)
                            .font(FMTypography.labelLarge)
                            .lineLimit(1)
                    }
                    .foregroundColor(isSelected ? FMColors.onPrimaryContainer : FMColors.onSurface)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(isSelected ? FMColors.primaryContainer : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if category != RankingCategory.allCases.last {
                    Rectangle().fill(FMColors.outline).frame(width: 1)
                }
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(FMColors.outline, lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Score helpers

enum RankingScoreText {
    static func unit(_ category: RankingCategory, count: Int) -> String {
        switch category {
        case .victories: return L10n.Ranking.victoryUnit(count)
        case .goals: return L10n.Ranking.goalUnit(count)
        }
    }

    static func displayName(_ player: RankingPlayer, isCurrentUser: Bool) -> String {
        if isCurrentUser { return L10n.Ranking.you }
        return player.name.isEmpty ? L10n.Ranking.playerFallback : player.name
    }
}

// MARK: - Avatar

/// Photo with the same fallbacks as Match Detail (gendered default avatar) and the
/// country flag in the corner.
struct RankingAvatar: View {
    let player: RankingPlayer
    let size: CGFloat
    let borderColor: Color

    var body: some View {
        FMAvatar(
            url: player.avatarUrl.flatMap(URL.init(string:)),
            defaultImageName: player.gender?.defaultAvatarAssetName ?? "defaultAvatar",
            size: size
        )
        .overlay(Circle().stroke(borderColor, lineWidth: 2))
        .overlay(alignment: .bottomTrailing) {
            if let flag = RankingFormatting.flag(for: player.country) {
                Text(flag)
                    .font(.system(size: max(10, size * 0.26)))
                    .offset(x: 2, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Podium

/// Second on the left, first in the middle, third on the right. Fewer than three players
/// draw only the slots that exist. Colors follow each player's `position`, so a 1, 1, 3
/// tie shows two golds.
struct RankingPodium: View {
    let players: [RankingPlayer]
    let category: RankingCategory

    private var slots: [Int] {
        switch players.count {
        case 1: return [0]
        case 2: return [1, 0]
        default: return [1, 0, 2]
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(slots, id: \.self) { index in
                slot(players[index], index: index)
            }
        }
        .padding(.vertical, 8)
    }

    /// Step height per podium slot (index in the server's order): first the tallest,
    /// then second, then third.
    private func stepHeight(_ index: Int) -> CGFloat {
        switch index {
        case 0: return 176
        case 1: return 142
        default: return 116
        }
    }

    private func slot(_ player: RankingPlayer, index: Int) -> some View {
        let colors = FMRankingMedalColors.forPosition(player.position)
        let prominent = index == 0
        let score = player.score(for: category)
        let unit = RankingScoreText.unit(category, count: score)
        let name = RankingScoreText.displayName(player, isCurrentUser: false)
        return VStack(spacing: 6) {
            Image(systemName: player.position == 1 ? "trophy.fill" : "medal.fill")
                .font(.system(size: prominent ? 22 : 17))
                .foregroundColor(colors.accent)
                .accessibilityHidden(true)
            RankingAvatar(player: player, size: prominent ? 76 : 60, borderColor: colors.accent)
                .padding(.bottom, 4)
            VStack(spacing: 4) {
                Text(name)
                    .font(FMTypography.labelLarge)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(L10n.Ranking.place(player.position))
                    .font(FMTypography.labelSmall)
                Spacer(minLength: 4)
                Text("\(score)")
                    .font(.interBold(size: prominent ? 30 : 26))
                Text(unit)
                    .font(FMTypography.labelSmall)
            }
            .foregroundColor(colors.onContainer)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: stepHeight(index))
            .background(RoundedRectangle(cornerRadius: 16).fill(colors.container))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colors.accent.opacity(0.35), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        // Each column keeps its own height; without this the Spacer stretches every
        // card to the tallest column and the steps disappear.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L10n.Ranking.place(player.position)), \(name), \(L10n.Ranking.scoreAccessibility(score, unit: unit))")
    }
}

// MARK: - Table

private enum RankingTableMetrics {
    static let positionWidth: CGFloat = 28
    static let matchesWidth: CGFloat = 30
    static let scoreWidth: CGFloat = 56
    static let horizontalPadding: CGFloat = 12
}

struct RankingTableHeader: View {
    let category: RankingCategory

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.Ranking.positionColumn)
                .frame(width: RankingTableMetrics.positionWidth)
            Text(L10n.Ranking.playerColumn)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.Ranking.matchesColumn)
                .frame(width: RankingTableMetrics.matchesWidth)
            Text(category == .victories ? L10n.Ranking.victoriesTab : L10n.Ranking.goalsColumn)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: RankingTableMetrics.scoreWidth)
        }
        .font(FMTypography.labelSmall)
        .foregroundColor(FMColors.onSurfaceVariant)
        .padding(.horizontal, RankingTableMetrics.horizontalPadding)
        .accessibilityHidden(true)
    }
}

/// One standings row. Your own row (matched by id) reads "You" and is highlighted.
struct RankingPlayerRow: View {
    let player: RankingPlayer
    let category: RankingCategory
    let isCurrentUser: Bool

    var body: some View {
        let medal = FMRankingMedalColors.forPosition(player.position)
        let hasMedal = FMRankingMedalColors.hasMedal(player.position)
        let score = player.score(for: category)
        let name = RankingScoreText.displayName(player, isCurrentUser: isCurrentUser)

        HStack(spacing: 8) {
            Text("\(player.position)")
                .font(FMTypography.labelLarge)
                .foregroundColor(hasMedal ? medal.onContainer : (isCurrentUser ? FMColors.onPrimaryContainer : FMColors.onSurface))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: RankingTableMetrics.positionWidth, height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(hasMedal ? medal.container : Color.clear))

            HStack(spacing: 8) {
                RankingAvatar(
                    player: player,
                    size: 32,
                    borderColor: isCurrentUser ? FMColors.primary : FMColors.outlineVariant
                )
                Text(name)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(isCurrentUser ? FMColors.onPrimaryContainer : FMColors.onSurface)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(player.matchesPlayed)")
                .font(FMTypography.bodyMedium)
                .foregroundColor(isCurrentUser ? FMColors.onPrimaryContainer : FMColors.onSurface)
                .frame(width: RankingTableMetrics.matchesWidth)

            Text("\(score)")
                .font(.interSemiBold(size: 16))
                .foregroundColor(isCurrentUser ? FMColors.onPrimary : FMColors.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: RankingTableMetrics.scoreWidth, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrentUser ? FMColors.primary : FMColors.surfaceContainerHigh)
                )
        }
        .padding(.horizontal, RankingTableMetrics.horizontalPadding)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrentUser ? FMColors.primaryContainer : FMColors.surfaceContainerLow)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? FMColors.primary : FMColors.outlineVariant, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(L10n.Ranking.place(player.position)), \(name), \(L10n.Ranking.matchesColumn) \(player.matchesPlayed), "
            + L10n.Ranking.scoreAccessibility(score, unit: RankingScoreText.unit(category, count: score))
        )
    }
}

// MARK: - Footer

struct RankingFooter: View {
    let calculatedAt: Int64
    let seasonTimeZone: String
    let showParticipationHint: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showParticipationHint {
                participationHint
            }
            aboutCard
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .accessibilityHidden(true)
                Text(L10n.Ranking.updatedAt(RankingFormatting.updatedAt(calculatedAt)))
                    .font(FMTypography.labelSmall)
            }
            .foregroundColor(FMColors.onSurfaceVariant)
            .padding(.horizontal, 6)
        }
    }

    private var participationHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "trophy.fill")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Ranking.joinTitle)
                    .font(FMTypography.titleSmall)
                Text(L10n.Ranking.notParticipating)
                    .font(FMTypography.bodySmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(FMColors.onPrimaryContainer)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(FMColors.primaryContainer))
        .accessibilityElement(children: .combine)
    }

    private var aboutCard: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Ranking.aboutTitle)
                            .font(FMTypography.titleSmall)
                            .foregroundColor(FMColors.onSurface)
                        Text(L10n.Ranking.aboutSummary)
                            .font(FMTypography.bodySmall)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .accessibilityHidden(true)
                }
                if isExpanded {
                    Divider()
                    Group {
                        Text(L10n.Ranking.matchesExplained)
                        Text(L10n.Ranking.resultsNote)
                        Text(L10n.Ranking.tiesNote)
                        Text(L10n.Ranking.timeZoneNote(
                            deviceZone: TimeZone.current.identifier,
                            seasonZone: seasonTimeZone
                        ))
                    }
                    .font(FMTypography.bodySmall)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                }
            }
            .foregroundColor(FMColors.onSurfaceVariant)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(FMColors.surfaceContainerLow))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMColors.outlineVariant, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? L10n.Ranking.aboutExpanded : L10n.Ranking.aboutCollapsed)
    }
}

// MARK: - Message

struct RankingMessage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundColor(FMColors.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onSurface)
                .multilineTextAlignment(.center)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
