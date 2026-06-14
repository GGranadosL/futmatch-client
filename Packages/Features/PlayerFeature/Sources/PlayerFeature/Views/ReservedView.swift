import SwiftUI
import FMDesignSystem

// MARK: - Tab

private enum ReservedTab: CaseIterable {
    case upcoming, finished, canceled

    func label() -> String {
        switch self {
        case .upcoming:  return L10n.Reserved.tabUpcoming
        case .finished:  return L10n.Reserved.tabFinished
        case .canceled:  return L10n.Reserved.tabCanceled
        }
    }
}

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
    @State private var selectedTab: ReservedTab = .upcoming

    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navigationPath = navigationPath
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L10n.Reserved.title)
                .font(FMTypography.headlineMedium)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Tab bar
            FMSegmentedTabBar(
                tabs: ReservedTab.allCases,
                selected: $selectedTab,
                labelFor: { $0.label() }
            )

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView().tint(FMColors.primary)
                Spacer()
            } else if let errorMessage = viewModel.error, viewModel.myMatches.isEmpty {
                FMFullScreenError(
                    title: viewModel.errorTitle ?? L10n.ErrorOverlay.title,
                    message: errorMessage,
                    retryTitle: L10n.Common.retry,
                    onRetry: { Task { await viewModel.load() } }
                )
            } else {
                tabContent
            }
        }
        .background(FMColors.background)
        .fmToast(
            viewModel.refreshErrorMessage ?? L10n.ErrorOverlay.refreshMessage,
            isPresented: $viewModel.refreshFailed,
            style: .error
        )
        .task { await viewModel.load() }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        let matches = filteredMatches(for: selectedTab)
        if matches.isEmpty {
            emptyState(for: selectedTab)
        } else {
            matchesList(matches)
        }
    }

    // MARK: - Filtering

    private func filteredMatches(for tab: ReservedTab) -> [MatchItem] {
        switch tab {
        case .upcoming:
            return viewModel.myMatches.filter {
                let s = $0.matchStatus.uppercased()
                return s != "COMPLETED" && s != "CANCELED" && s != "CANCELLED"
            }
        case .finished:
            return viewModel.myMatches.filter {
                $0.matchStatus.uppercased() == "COMPLETED"
            }
        case .canceled:
            return viewModel.myMatches.filter {
                let s = $0.matchStatus.uppercased()
                return s == "CANCELED" || s == "CANCELLED"
            }
        }
    }

    // MARK: - Matches List

    private func matchesList(_ matches: [MatchItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let sections = groupByDate(matches)
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
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
        .refreshable { await Task { await viewModel.load() }.value }
    }

    // MARK: - Date Grouping

    private func groupByDate(_ matches: [MatchItem]) -> [ReservedSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEEE d"

        var grouped: [Date: [MatchItem]] = [:]
        for match in matches {
            grouped[calendar.startOfDay(for: match.startDate), default: []].append(match)
        }

        // Upcoming: ascending. Finished/Canceled: descending (most recent first)
        let ascending = selectedTab == .upcoming
        let sortedDays = grouped.keys.sorted { ascending ? $0 < $1 : $0 > $1 }

        return sortedDays.compactMap { day in
            let dayMatches = (grouped[day] ?? []).sorted {
                ascending ? $0.startDate < $1.startDate : $0.startDate > $1.startDate
            }
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

    // MARK: - Section Header

    private func sectionHeader(_ title: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            if showDivider {
                Divider().padding(.horizontal, 16)
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

    // MARK: - Match Card

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
            distance: match.distanceDisplay,
            fieldImageUrl: match.fieldImageUrl,
            onTap: { navigationPath.append(match) }
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
            Text(title).font(FMTypography.labelMedium)
            Text("\(value)").font(FMTypography.headlineMedium).bold()
        }
    }

    private func statusTitle(for status: String) -> String {
        switch status {
        case "COMPLETED":  return L10n.Reserved.tabFinished
        case "CANCELED", "CANCELLED": return L10n.Reserved.tabCanceled
        default: return status
        }
    }

    // MARK: - Empty States

    private func emptyState(for tab: ReservedTab) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 80)
                Image("emptyStateReserved", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(emptyTitle(for: tab))
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .bold()
                    .multilineTextAlignment(.center)
                Text(L10n.Reserved.emptySubtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable { await Task { await viewModel.load() }.value }
    }

    private func emptyTitle(for tab: ReservedTab) -> String {
        switch tab {
        case .upcoming:  return L10n.Reserved.emptyUpcoming
        case .finished:  return L10n.Reserved.emptyFinished
        case .canceled:  return L10n.Reserved.emptyCanceled
        }
    }
}

// MARK: - Preview

#Preview {
    ReservedView()
        .environmentObject(ReservedMatchesViewModel(fetchMyMatchesUseCase: PlayerDependencyFactory().makeFetchMyMatchesUseCase()))
}
