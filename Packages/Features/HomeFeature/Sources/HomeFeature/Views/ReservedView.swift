import SwiftUI
import FMDesignSystem

// MARK: - Section Model

private struct ReservedSection: Identifiable {
    let id = UUID()
    let title: String
    let matches: [MatchItem]
}

// MARK: - Reserved Matches Screen

struct ReservedView: View {
    @EnvironmentObject private var viewModel: ReservedMatchesViewModel
    @Binding var navigationPath: NavigationPath

    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navigationPath = navigationPath
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.Reserved.title)
                .font(FMTypography.headlineMedium)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.myMatches.isEmpty {
                emptyState
            } else {
                matchesList
            }
        }
        .background(FMColors.background)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Matches List

    private var matchesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(reservedSections.enumerated()), id: \.element.id) { index, section in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(section.matches) { match in
                                reservedCard(for: match)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    } header: {
                        sectionHeader(section.title, showDivider: index > 0)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    /// Groups matches into date sections
    private var reservedSections: [ReservedSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEEE d"

        var grouped: [Date: [MatchItem]] = [:]
        for match in viewModel.myMatches {
            grouped[calendar.startOfDay(for: match.startDate), default: []].append(match)
        }

        return grouped.keys.sorted().compactMap { day in
            let dayMatches = grouped[day] ?? []
            guard !dayMatches.isEmpty else { return nil }
            let title: String
            if calendar.isDate(day, inSameDayAs: today) {
                title = L10n.Matches.today
            } else if calendar.isDate(day, inSameDayAs: tomorrow) {
                title = L10n.Matches.tomorrow
            } else {
                title = fmt.string(from: day).capitalized
            }
            return ReservedSection(title: title, matches: dayMatches)
        }
    }

    private func sectionHeader(_ title: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
            Text(title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 4)
        }
    }

    private func reservedCard(for match: MatchItem) -> some View {
        let status = match.matchStatus.uppercased()
        let isDimmed = status == "COMPLETED" || status == "CANCELED" || status == "CANCELLED"

        return FMMatchCard(
            venueName: match.venueName,
            timeRange: match.timeRange,
            price: match.price,
            matchType: match.matchType,
            spotsLeft: match.spotsLeft,
            spotsLabel: L10n.Matches.spotsLeft(match.spotsLeft),
            teamA: FMMatchTeam(
                name: L10n.Matches.teamA,
                avatarURLs: match.teamAPlayers.prefix(3).map { $0.avatarUrl },
                playerCount: match.teamAPlayers.count
            ),
            teamB: FMMatchTeam(
                name: L10n.Matches.teamB,
                avatarURLs: match.teamBPlayers.prefix(3).map { $0.avatarUrl },
                playerCount: match.teamBPlayers.count
            ),
            distance: match.distance,
            fieldImageUrl: match.fieldImageUrl,
            onTap: {
                navigationPath.append(match)
            }
        )
        .overlay {
            if isDimmed {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.58))
                    .overlay {
                        VStack(spacing: 10) {
                            if status == "COMPLETED" {
                                HStack(spacing: 18) {
                                    scoreColumn(title: L10n.Matches.teamA, value: match.teamAPlayers.count)
                                    scoreColumn(title: L10n.Matches.teamB, value: match.teamBPlayers.count)
                                }
                            }

                            HStack(spacing: 8) {
                                Image(systemName: status == "COMPLETED" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(statusTitle(for: status))
                                    .font(FMTypography.titleLarge)
                                    .bold()
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .allowsHitTesting(false)
            }
        }
    }

    private func scoreColumn(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(FMTypography.labelMedium)
            Text("\(value)")
                .font(FMTypography.headlineMedium)
                .bold()
        }
    }

    private func statusTitle(for status: String) -> String {
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"

        switch status {
        case "COMPLETED":
            return isSpanish ? "Finalizado" : "Completed"
        case "CANCELED", "CANCELLED":
            return isSpanish ? "Cancelado" : "Canceled"
        default:
            return status
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("emptyStateReserved", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text(L10n.Reserved.empty)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .bold()
                .multilineTextAlignment(.center)
            Text(L10n.Reserved.emptySubtitle)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    ReservedView()
        .environmentObject(ReservedMatchesViewModel(fetchMyMatchesUseCase: HomeDependencyFactory().makeFetchMyMatchesUseCase()))
}
