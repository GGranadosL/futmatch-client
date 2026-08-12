import SwiftUI
import FMDesignSystem
import SharedModels

// MARK: - OrganizerHomeView

/// Home screen for users with the `ORGANIZER` role. Read-only match supervision:
/// the list comes from `/match/organizer/matches` (only the matches this organizer
/// supervises), and there is no create-match entry point — creating matches is
/// admin-only. No fields or locations either.
public struct OrganizerHomeView: View {
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: AdminMatchesViewModel
    @State private var selectedTab: AdminMatchListTab = .upcoming
    @State private var selectedMatch: AdminMatch? = nil

    private let factory: AdminDependencyFactory

    public init() {
        let factory = AdminDependencyFactory()
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeOrganizerMatchesViewModel())
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            greetingSection
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .modifier(OrganizerHideTabBarModifier())
        .task { await viewModel.load() }
        .navigationDestination(isPresented: Binding(
            get: { selectedMatch != nil },
            set: { if !$0 { selectedMatch = nil } }
        )) {
            if let match = selectedMatch {
                AdminMatchDetailView(
                    viewModel: factory.makeAdminMatchDetailViewModel(match: match),
                    factory: factory,
                    subtitle: L10n.OrganizerHome.roleBadge
                )
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            HStack {
                FMBrandLogo()
                Spacer()
                if #available(iOS 26.0, *) {
                    playerButton
                        .glassEffect(.regular.interactive(), in: .circle)
                } else {
                    playerButton
                }
            }

            Text("organizer")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FMColors.primary)
                .kerning(1.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var playerButton: some View {
        Button {
            dismiss()
        } label: {
            Image("player_panel", bundle: .main)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(FMColors.onSurface)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.OrganizerHome.roleBadge)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text(L10n.OrganizerHome.greeting(userSession.currentUser?.name ?? ""))
                .font(FMTypography.headlineMedium)
                .foregroundColor(FMColors.onBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Main Content

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

    // MARK: - List Header

    private var listHeader: some View {
        Text(L10n.OrganizerHome.matchesTitle)
            .font(FMTypography.titleLarge)
            .foregroundColor(FMColors.onBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
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

// MARK: - Hide Tab Bar

private struct OrganizerHideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}
