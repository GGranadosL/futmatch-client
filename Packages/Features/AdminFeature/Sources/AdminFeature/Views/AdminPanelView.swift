import CoreData
import SwiftUI
import FMDesignSystem
import SharedModels

// MARK: - AdminPanelView

/// Admin home screen. Reached from the admin button in the player home header
/// (only visible to users with `UserRole.administrator`). The top-right button
/// returns to the player view.
public struct AdminPanelView: View {
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: AdminHomeViewModel
    @State private var showNewField = false
    @State private var showFields = false
    @State private var showNewLocation = false
    @State private var showLocationsList = false
    @State private var locations: [AdminLocation] = []

    private let factory: AdminDependencyFactory

    public init() {
        let factory = AdminDependencyFactory()
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeAdminHomeViewModel())
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingSection
                    actionsSection
                    statsCarousel
                    upcomingMatchesSection
                }
                .padding(.bottom, 32)
            }
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .modifier(HideTabBarModifier())
        .navigationDestination(isPresented: $showNewField) {
            NewFieldView(
                viewModel: factory.makeNewFieldViewModel(),
                onCreated: {
                    Task {
                        await viewModel.load()
                        showNewField = false
                        // Small delay to ensure the dismiss animation completes before
                        // the second navigation begins, avoiding state conflicts.
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        showFields = true
                    }
                }
            )
            .modifier(HideTabBarModifier())
        }
        .navigationDestination(isPresented: $showFields) {
            AdminFieldsListView(
                viewModel: factory.makeAdminFieldsViewModel(context: context),
                factory: factory,
                remoteConfig: AdminRemoteConfig()
            )
            .modifier(HideTabBarModifier())
        }
        .navigationDestination(isPresented: $showNewLocation) {
            NewLocationView(
                viewModel: factory.makeNewLocationViewModel(context: context),
                onCreated: {
                    Task {
                        await loadLocations()
                        showNewLocation = false
                        // Small delay to ensure the dismiss animation completes before
                        // the second navigation begins, avoiding state conflicts.
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        showLocationsList = true
                    }
                }
            )
            .modifier(HideTabBarModifier())
        }
        .navigationDestination(isPresented: $showLocationsList) {
            AdminLocationsListView(factory: factory, context: context)
                .modifier(HideTabBarModifier())
        }
        .task {
            await viewModel.load()
            await loadLocations()
        }
    }

    private func loadLocations() async {
        let useCase = factory.makeFetchLocationsUseCase(context: context)
        if let result = try? await useCase.execute() {
            locations = result
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            FMBrandLogo()

            Spacer()

            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    playerButton
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            } else {
                playerButton
            }
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
            Text("ADMINISTRADOR")
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text("Hola, \(userSession.currentUser?.name ?? "")")
                .font(FMTypography.headlineMedium)
                .foregroundColor(FMColors.onBackground)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            AdminActionCard(icon: "soccerball", title: "Nuevo partido")
            AdminActionCard(icon: "sportscourt.fill", title: "Nueva cancha") {
                showNewField = true
            }
            AdminActionCard(icon: "mappin.and.ellipse", title: "Nueva ubicación") {
                showNewLocation = true
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Stats Carousel

    private var statsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(
                    icon: "calendar",
                    value: scheduledMatchesCount,
                    label: "Partidos\nprogramados"
                )
                statCard(
                    icon: "sportscourt.fill",
                    value: registeredVenuesCount,
                    label: "Canchas\nregistradas"
                ) {
                    showFields = true
                }
                statCard(
                    icon: "mappin.circle.fill",
                    value: registeredLocationsCount,
                    label: "Ubicaciones\nregistradas"
                ) {
                    showLocationsList = true
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func statCard(
        icon: String,
        value: Int,
        label: String,
        onTap: (() -> Void)? = nil
    ) -> some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(FMColors.primary)
                    .padding(8)
                    .background(Circle().fill(FMColors.primaryContainer))

                Text(String(format: "%02d", value))
                    .font(FMTypography.headlineSmall)
                    .foregroundColor(FMColors.onSurface)
                    .bold()

                Text(label)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 110)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    // MARK: - Upcoming Matches

    private var upcomingMatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Próximos Partidos")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                Spacer()
                Button {
                    // TODO: Navigate to the full admin matches list.
                } label: {
                    Text("Ver todos")
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)
                }
            }
            .padding(.horizontal, 24)

            if upcomingMatches.isEmpty {
                FMEmptyStateCard(
                    icon: "soccerball",
                    message: "No hay partidos programados"
                )
                .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(upcomingMatches) { match in
                        AdminMatchRow(match: match)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Derived State

    private var dashboard: AdminDashboard? {
        if case let .loaded(dashboard) = viewModel.state { return dashboard }
        return nil
    }

    private var scheduledMatchesCount: Int { dashboard?.scheduledMatchesCount ?? 0 }
    private var registeredVenuesCount: Int { dashboard?.registeredVenuesCount ?? 0 }
    private var registeredLocationsCount: Int { locations.count }
    private var upcomingMatches: [AdminUpcomingMatch] { dashboard?.upcomingMatches ?? [] }
}

// MARK: - Hide Tab Bar Modifier

/// Hides the system tab bar when this view is pushed onto a NavigationStack.
/// Works on iOS 16+ (deployment target).
private struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AdminPanelView()
            .environmentObject(UserSession())
    }
}
