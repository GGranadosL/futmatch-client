import SwiftUI
import FMDesignSystem
import SharedModels

/// Read-only public profile of another player, fetched from /profiles/{userId}.
struct PlayerProfileView: View {
    @StateObject private var viewModel: PlayerProfileViewModel
    @Environment(\.dismiss) private var dismiss

    init(userId: String, isDemoMode: Bool = false) {
        let factory = PlayerDependencyFactory(isDemoMode: isDemoMode)
        _viewModel = StateObject(wrappedValue: factory.makePlayerProfileViewModel(userId: userId))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(FMColors.background)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Content by State

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingSkeleton
        case .failed(let message):
            Spacer()
            VStack(spacing: 12) {
                Text(message)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button(L10n.Common.retry) {
                    Task { await viewModel.load() }
                }
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.primary)
            }
            .padding(.horizontal, 32)
            Spacer()
        case .loaded(let profile):
            loadedBody(profile)
        }
    }

    private func loadedBody(_ profile: PublicPlayerProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                avatarSection(profile)
                nameSection(profile)
                statsSection(profile.stats)
                performanceSection(profile)
                if let last = profile.lastMatch {
                    lastMatchSection(last)
                }
            }
            .padding(.bottom, 40)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Avatar + position pill
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        FMSkeleton(cornerRadius: 50)
                            .frame(width: 100, height: 100)
                        FMSkeleton(cornerRadius: 14)
                            .frame(width: 110, height: 28)
                            .offset(y: -14)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Name + country
                VStack(alignment: .leading, spacing: 8) {
                    FMSkeleton(cornerRadius: 6).frame(width: 200, height: 28)
                    FMSkeleton(cornerRadius: 4).frame(width: 90, height: 16)
                }
                .padding(.horizontal, 24)

                // Estadísticas
                VStack(alignment: .leading, spacing: 12) {
                    FMSkeleton(cornerRadius: 6).frame(width: 140, height: 24)
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeleton(cornerRadius: 16).frame(width: 100, height: 110)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Rendimiento
                VStack(alignment: .leading, spacing: 12) {
                    FMSkeleton(cornerRadius: 6).frame(width: 140, height: 24)
                    FMSkeleton(cornerRadius: 16).frame(maxWidth: .infinity).frame(height: 110)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Avatar (with position badge)

    private func avatarSection(_ profile: PublicPlayerProfile) -> some View {
        HStack {
            FMAvatar(
                url: profile.profilePicURL,
                defaultImageName: profile.gender?.defaultAvatarAssetName ?? "defaultAvatar",
                size: 100,
                showCameraBadge: false
            )
            .overlay(
                Circle().stroke(FMColors.outlineVariant, lineWidth: 2)
            )
            .overlay(alignment: .bottom) {
                Text(profile.playerPosition.displayName)
                    .font(FMTypography.labelMedium)
                    .foregroundColor(FMColors.onTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(FMColors.tertiary))
                    .offset(y: 12)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Name + Country

    private func nameSection(_ profile: PublicPlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(profile.fullName)
                .font(FMTypography.headlineSmall)
                .foregroundColor(FMColors.onBackground)
                .padding(.top, 12)

            HStack(spacing: 4) {
                Text(countryFlag(profile.country))
                    .font(.system(size: 14))
                Text(countryDisplayName(profile.country))
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Stats

    private func statsSection(_ stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.statistics)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FMStatCard(icon: "trophy.fill", value: stats.mvpCount,      label: L10n.Profile.mvp)
                    FMStatCard(icon: "star.fill",   value: stats.matchesWon,    label: L10n.Profile.won)
                    FMStatCard(icon: "sportscourt", value: stats.matchesPlayed, label: L10n.Profile.played)
                    FMStatCard(icon: "soccerball",  value: stats.totalGoals,    label: L10n.Profile.totalGoals)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Performance

    private func performanceSection(_ profile: PublicPlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.performance)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Profile.playerLevel)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    Text(profile.level.displayName)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(FMColors.tertiary))
                }

                Spacer()

                FMOVRRing(score: profile.averageScore)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Last Match

    private func lastMatchSection(_ last: PlayerLastMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.LastMatch.title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            HStack(spacing: 14) {
                Image(systemName: outcomeIcon(last.outcome))
                    .font(.system(size: 24))
                    .foregroundColor(outcomeColor(last.outcome))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(outcomeColor(last.outcome).opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(outcomeLabel(last.outcome))
                        .font(FMTypography.titleSmall)
                        .foregroundColor(FMColors.onSurface)
                    Text("\(relativeDate(last.playedAt)) - \(last.fieldName)")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Text("\(last.teamAScore) - \(last.teamBScore)")
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(FMColors.onSurface)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func outcomeIcon(_ outcome: String) -> String {
        switch outcome.uppercased() {
        case "WIN":  return "trophy.fill"
        case "LOSS", "LOSE": return "xmark.circle.fill"
        default:     return "equal.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: String) -> Color {
        switch outcome.uppercased() {
        case "WIN":  return .green
        case "LOSS", "LOSE": return .red
        default:     return .orange
        }
    }

    private func outcomeLabel(_ outcome: String) -> String {
        switch outcome.uppercased() {
        case "WIN":  return L10n.LastMatch.win
        case "LOSS", "LOSE": return L10n.LastMatch.loss
        default:     return L10n.LastMatch.draw
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private func countryFlag(_ country: String) -> String {
        let iso = country.uppercased()
        guard iso.count == 2, iso.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else {
            return "🏳️"
        }
        return iso.unicodeScalars.map { String(Unicode.Scalar($0.value + 127397)!) }.joined()
    }

    private func countryDisplayName(_ country: String) -> String {
        Locale.current.localizedString(forRegionCode: country) ?? country
    }
}
