import SwiftUI
import FMDesignSystem

// MARK: - Tab

private enum AdminMatchTab: CaseIterable {
    case upcoming, finished, canceled

    func label() -> String {
        switch self {
        case .upcoming:  return "Próximos"
        case .finished:  return "Finalizados"
        case .canceled:  return "Cancelados"
        }
    }
}

// MARK: - Section Model

private struct AdminMatchSection: Identifiable {
    let id = UUID()
    let title: String
    let matches: [AdminMatch]
}

// MARK: - AdminMatchesListView

struct AdminMatchesListView: View {
    @StateObject private var viewModel: AdminMatchesViewModel
    @Environment(\.dismiss) private var dismiss

    private let factory: AdminDependencyFactory
    @State private var selectedTab: AdminMatchTab = .upcoming
    @State private var showNewMatch = false

    init(
        viewModel: @autoclosure @escaping () -> AdminMatchesViewModel,
        factory: AdminDependencyFactory
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.factory = factory
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            mainContent
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.AdminMatches.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewMatch = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $showNewMatch) {
            NewMatchView(
                viewModel: factory.makeNewMatchViewModel(),
                onCreated: {
                    showNewMatch = false
                    Task { await viewModel.load() }
                }
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            skeletonList

        case .loaded(let matches):
            VStack(spacing: 0) {
                FMSegmentedTabBar(
                    tabs: AdminMatchTab.allCases,
                    selected: $selectedTab,
                    labelFor: { $0.label() }
                )
                let filtered = filteredMatches(matches, for: selectedTab)
                if filtered.isEmpty {
                    emptyTab(for: selectedTab)
                } else {
                    matchesList(filtered)
                }
            }

        case .empty:
            VStack(spacing: 0) {
                FMSegmentedTabBar(
                    tabs: AdminMatchTab.allCases,
                    selected: $selectedTab,
                    labelFor: { $0.label() }
                )
                FMEmptyStateCard(icon: "soccerball", message: "No hay partidos registrados")
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
            }

        case .failed(let message):
            FMFullScreenError(
                title: "Error",
                message: message,
                retryTitle: "Reintentar",
                onRetry: { Task { await viewModel.load() } }
            )
        }
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    FMSkeleton(cornerRadius: 6).frame(width: 180, height: 24)
                    FMSkeleton(cornerRadius: 4).frame(width: 260, height: 14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in AdminMatchRowSkeleton() }
                }
                .padding(.horizontal, 24)
            }
        }
        .disabled(true)
    }

    // MARK: - Matches List

    private func matchesList(_ matches: [AdminMatch]) -> some View {
        let ascending = selectedTab == .upcoming
        let sections = groupByDate(matches, ascending: ascending)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                listHeader
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(section.matches) { match in
                                    AdminMatchCard(match: match)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        } header: {
                            sectionHeader(section.title, showDivider: index > 0)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .refreshable { await viewModel.load() }
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AdminMatches.heading)
                .font(FMTypography.headlineSmall)
                .foregroundColor(FMColors.onBackground)
            Text(L10n.AdminMatches.description)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func sectionHeader(_ title: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            if showDivider { Divider().padding(.horizontal, 24) }
            Text(title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Empty Tab State

    private func emptyTab(for tab: AdminMatchTab) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 80)
                Image(systemName: "soccerball")
                    .font(.system(size: 40))
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(emptyTitle(for: tab))
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .bold()
                    .multilineTextAlignment(.center)
                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
        .refreshable { await viewModel.load() }
    }

    private func emptyTitle(for tab: AdminMatchTab) -> String {
        switch tab {
        case .upcoming:  return "No hay partidos próximos"
        case .finished:  return "No hay partidos finalizados"
        case .canceled:  return "No hay partidos cancelados"
        }
    }

    // MARK: - Filtering

    private func filteredMatches(_ matches: [AdminMatch], for tab: AdminMatchTab) -> [AdminMatch] {
        switch tab {
        case .upcoming:  return matches.filter { $0.status == .scheduled || $0.status == .inProgress }
        case .finished:  return matches.filter { $0.status == .completed }
        case .canceled:  return matches.filter { $0.status == .canceled }
        }
    }

    // MARK: - Date Grouping

    private func groupByDate(_ matches: [AdminMatch], ascending: Bool) -> [AdminMatchSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEEE d"

        var grouped: [Date: [AdminMatch]] = [:]
        for match in matches {
            grouped[calendar.startOfDay(for: match.startDate), default: []].append(match)
        }

        return grouped.keys
            .sorted { ascending ? $0 < $1 : $0 > $1 }
            .compactMap { day in
                let dayMatches = (grouped[day] ?? []).sorted {
                    ascending ? $0.startDate < $1.startDate : $0.startDate > $1.startDate
                }
                guard !dayMatches.isEmpty else { return nil }

                let title: String
                if calendar.isDate(day, inSameDayAs: today) {
                    title = "Hoy"
                } else if calendar.isDate(day, inSameDayAs: tomorrow) {
                    title = "Mañana"
                } else {
                    title = fmt.string(from: day).capitalized
                }
                return AdminMatchSection(title: title, matches: dayMatches)
            }
    }
}
