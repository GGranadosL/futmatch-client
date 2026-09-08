import SwiftUI
import FMDesignSystem

// MARK: - AdminMatchesListView

struct AdminMatchesListView: View {
    @StateObject private var viewModel: AdminMatchesViewModel
    @Environment(\.dismiss) private var dismiss

    private let factory: AdminDependencyFactory
    @State private var selectedTab: AdminMatchListTab = .upcoming
    @State private var showNewMatch = false
    @State private var selectedMatch: AdminMatch? = nil

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
        .toolbar {
            ToolbarItem(placement: .principal) {
                AdminNavTitle(title: L10n.AdminMatches.title)
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
        .navigationDestination(isPresented: Binding(
            get: { selectedMatch != nil },
            set: { if !$0 { selectedMatch = nil } }
        )) {
            if let match = selectedMatch {
                AdminMatchDetailView(
                    viewModel: factory.makeAdminMatchDetailViewModel(match: match),
                    factory: factory
                )
            }
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
                listHeader
                FMSegmentedTabBar(
                    tabs: AdminMatchListTab.allCases,
                    selected: $selectedTab,
                    labelFor: { $0.label }
                )
                let filtered = selectedTab.filter(matches)
                if filtered.isEmpty {
                    emptyTab(for: selectedTab)
                } else {
                    matchesList(filtered)
                }
            }

        case .empty:
            VStack(spacing: 0) {
                listHeader
                FMSegmentedTabBar(
                    tabs: AdminMatchListTab.allCases,
                    selected: $selectedTab,
                    labelFor: { $0.label }
                )
                FMEmptyStateCard(icon: "soccerball", message: L10n.AdminMatches.emptyAll)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
            }

        case .failed(let message):
            FMFullScreenError(
                title: L10n.Common.errorTitle,
                message: message,
                retryTitle: L10n.Common.retry,
                onRetry: { Task { await viewModel.load() } }
            )
        }
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        VStack(spacing: 0) {
            listHeader
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in AdminMatchRowSkeleton() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .disabled(true)
    }

    // MARK: - Matches List

    private func matchesList(_ matches: [AdminMatch]) -> some View {
        let sections = AdminMatchListGrouping.sections(matches, tab: selectedTab)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(section.matches) { match in
                                    AdminMatchCard(match: match, onTap: { selectedMatch = match })
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func emptyTab(for tab: AdminMatchListTab) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 80)
                Image(systemName: "soccerball")
                    .font(.system(size: 40))
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(tab.emptyMessage)
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
}
