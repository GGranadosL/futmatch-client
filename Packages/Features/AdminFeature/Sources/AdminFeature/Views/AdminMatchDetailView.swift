import SwiftUI
import UIKit
import MapKit
import FMDesignSystem

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, Color.white.opacity(0.4), .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            phase = 1.5
                        }
                    }
                }
            )
            .clipped()
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - HideTabBarModifier

private struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}

// MARK: - AdminMatchDetailView

struct AdminMatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AdminMatchDetailViewModel

    @State private var showMapPicker = false
    @State private var showEditMatch = false
    @State private var showSupervision = false
    @State private var showCancelNoPay = false
    @State private var showCancelWithPay = false
    @State private var showCancelReasonSheet = false
    @State private var showCancelSuccessToast = false
    @State private var showCompleteSuccessToast = false
    @State private var highlightedDropId: String? = nil

    private let factory: AdminDependencyFactory
    private let navSubtitle: String

    init(viewModel: AdminMatchDetailViewModel, factory: AdminDependencyFactory, subtitle: String = "admin") {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.factory = factory
        self.navSubtitle = subtitle
    }

    private var match: AdminMatch { viewModel.match }
    private var canEdit: Bool { match.status == .scheduled }
    private var canTakeAction: Bool { match.status != .completed && match.status != .canceled }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                    infoBar
                    lineupSection
                    if let field = viewModel.field {
                        fieldDetailsSection(field: field)
                    }
                    let rules = viewModel.rules
                    if !rules.isEmpty {
                        rulesSection(rules: rules)
                            .padding(.bottom, canTakeAction ? 96 : 16)
                    } else {
                        Spacer().frame(height: canTakeAction ? 80 : 0)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            if canTakeAction {
                HStack {
                    Spacer()
                    AdminMatchDetailActionBar(
                        canEdit: canEdit,
                        onEdit: { showEditMatch = true },
                        onCancel: {
                            if viewModel.isInPaidWindow {
                                showCancelWithPay = true
                            } else {
                                showCancelNoPay = true
                            }
                        },
                        onComplete: { showSupervision = true }
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }

            if showCancelNoPay || showCancelWithPay {
                FMConfirmationAlert(
                    icon: "info.circle.fill",
                    iconColor: FMColors.error,
                    iconBackgroundColor: FMColors.error.opacity(0.15),
                    title: L10n.CancelMatch.title,
                    message: showCancelWithPay
                        ? L10n.CancelMatch.withPayMessage
                        : L10n.CancelMatch.noPayMessage,
                    primaryButtonTitle: L10n.CancelMatch.confirmButton,
                    primaryButtonColor: FMColors.error,
                    secondaryButtonTitle: L10n.CancelMatch.backButton,
                    isLoading: false,
                    onPrimaryAction: {
                        showCancelNoPay = false
                        showCancelWithPay = false
                        showCancelReasonSheet = true
                    },
                    onSecondaryAction: {
                        showCancelNoPay = false
                        showCancelWithPay = false
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
        }
        .modifier(HideTabBarModifier())
        .navigationDestination(isPresented: $showEditMatch) {
            EditMatchView(
                viewModel: factory.makeEditMatchViewModel(match: match),
                subtitle: navSubtitle,
                onUpdated: { showEditMatch = false }
            )
        }
        .navigationDestination(isPresented: $showSupervision) {
            MatchSupervisionView(
                viewModel: factory.makeMatchSupervisionViewModel(match: match),
                onCompleted: {
                    showSupervision = false
                    showCompleteSuccessToast = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        dismiss()
                    }
                }
            )
        }
        .onChange(of: viewModel.cancelSucceeded) { succeeded in
            guard succeeded else { return }
            showCancelReasonSheet = false
            showCancelSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                dismiss()
            }
        }
        .fmToast(L10n.CancelMatch.canceledSuccess, isPresented: $showCancelSuccessToast, style: .success)
        .fmToast(L10n.MatchSupervision.completedSuccess, isPresented: $showCompleteSuccessToast, style: .success)
        .sheet(isPresented: $showCancelReasonSheet, onDismiss: { viewModel.clearCancelError() }) {
            CancelMatchReasonBottomSheet(
                isLoading: viewModel.isCanceling,
                errorMessage: viewModel.cancelError,
                onConfirm: { reason in
                    Task {
                        await viewModel.cancelMatch(reason: reason)
                    }
                },
                onBack: { showCancelReasonSheet = false }
            )
            .interactiveDismissDisabled(viewModel.isCanceling)
        }
        .alert(
            L10n.AdminMatchDetail.rebalanceError,
            isPresented: Binding(get: { viewModel.rebalanceError != nil }, set: { _ in viewModel.clearRebalanceError() })
        ) {
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(viewModel.rebalanceError ?? "")
        }
        .task { await viewModel.loadField() }
        .task { await viewModel.subscribeToPlayers() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            FMRemoteImage(urlString: match.fieldImageUrl) {
                Image("defaultField", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
            .scaledToFill()
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(match.gender.displayName)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(FMColors.secondaryFixed))

                Text(match.fieldName)
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(.white)
                    .bold()

                locationRow
            }
            .padding(20)
        }
    }

    // MARK: - Location Row

    @ViewBuilder
    private var locationRow: some View {
        let locationText = match.address ?? ""
        if !locationText.isEmpty {
            if match.coordinate != nil {
                Button { showMapPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                        Text(locationText).font(FMTypography.bodySmall).multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .confirmationDialog(
                    L10n.AdminMatchDetail.openInMapsTitle,
                    isPresented: $showMapPicker,
                    titleVisibility: .visible
                ) {
                    Button(L10n.AdminMatchDetail.openAppleMaps) { openInAppleMaps() }
                    if isGoogleMapsInstalled {
                        Button(L10n.AdminMatchDetail.openGoogleMaps) {
                            if let coord = match.coordinate { openInGoogleMaps(coord) }
                        }
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                    Text(locationText).font(FMTypography.bodySmall)
                }
                .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var isGoogleMapsInstalled: Bool {
        UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
    }

    private func openInAppleMaps() {
        guard let coordinate = match.coordinate else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = match.fieldName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate)])
    }

    private func openInGoogleMaps(_ coordinate: CLLocationCoordinate2D) {
        let urlString = "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)&center=\(coordinate.latitude),\(coordinate.longitude)&zoom=16"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Info Bar

    private var infoBar: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    Text("\(match.dateLabel) · \(match.timeRange)")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurface)
                }
                Spacer()
                Text(match.price)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    Text(match.duration)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill").font(.system(size: 12))
                    Text(L10n.AdminMatchDetail.spotsLeft(liveSpotsLeft))
                        .font(FMTypography.labelSmall)
                }
                .foregroundColor(FMColors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(FMColors.primaryContainer))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMColors.outlineVariant, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    /// Spots remaining, derived from the live Firestore roster so the badge
    /// tracks joins/leaves while the screen stays open. Falls back to the REST
    /// snapshot until the first Firestore snapshot arrives.
    private var liveSpotsLeft: Int {
        guard let liveA = viewModel.liveTeamAPlayers,
              let liveB = viewModel.liveTeamBPlayers else { return match.spotsLeft }
        return max(0, match.spotsTotal - (liveA.count + liveB.count))
    }

    // MARK: - Lineup Section

    private var lineupSection: some View {
        let isLoading = viewModel.liveTeamAPlayers == nil || viewModel.liveTeamBPlayers == nil
        let hasError = viewModel.playersError != nil
        let liveA = viewModel.liveTeamAPlayers ?? []
        let liveB = viewModel.liveTeamBPlayers ?? []
        // Capacity is fixed per match — the live roster must NOT alter it.
        // Deriving it from `match.spotsLeft` (a frozen REST snapshot) plus the
        // live Firestore counts made both teams lose a slot whenever anyone
        // left, because the total dropped by 1 and the `/ 2` truncated it.
        // That also silently removed a drag-and-drop target for rebalancing.
        let perTeamMax = max(1, match.spotsTotal / 2)
        let maxA = max(perTeamMax, liveA.count)
        let maxB = max(perTeamMax, liveB.count)

        return VStack(alignment: .leading, spacing: 16) {
            Text(L10n.AdminMatchDetail.currentLineup)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            if hasError {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FMColors.error)
                        Text(L10n.AdminMatchDetail.playersLoadError)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                        Spacer()
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.errorContainer))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.error.opacity(0.3), lineWidth: 1))
            } else if isLoading {
                skeletonTeamCard(name: L10n.AdminMatchDetail.teamA)
                skeletonTeamCard(name: L10n.AdminMatchDetail.teamB)
            } else {
                teamLineup(name: L10n.AdminMatchDetail.teamA, team: "A", players: liveA, maxPlayers: maxA)
                teamLineup(name: L10n.AdminMatchDetail.teamB, team: "B", players: liveB, maxPlayers: maxB)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Team Card

    private func teamLineup(name: String, team: String, players: [AdminMatchPlayer], maxPlayers: Int) -> some View {
        let emptyCount = max(0, maxPlayers - players.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onBackground)
                Spacer()
                Text(L10n.AdminMatchDetail.playerCount(players.count, maxPlayers))
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        playerSlot(player: player, team: team)
                    }
                    ForEach(0..<emptyCount, id: \.self) { index in
                        emptySlot(team: team, index: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Player Slot

    private func playerSlot(player: AdminMatchPlayer, team: String) -> some View {
        let dropId = player.id
        return VStack(spacing: 4) {
            ZStack {
                if player.status == .reserved {
                    Circle()
                        .fill(FMColors.surfaceContainerHigh)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(FMColors.primary.opacity(0.6))
                        )
                        .overlay(Circle().stroke(FMColors.primary, lineWidth: 2).padding(1))
                } else {
                    playerAvatar(url: player.avatarUrl, size: 44)
                }
            }
            .overlay(
                Circle()
                    .stroke(FMColors.primary, lineWidth: 2)
                    .opacity(highlightedDropId == dropId ? 1 : 0)
            )
            .overlay(alignment: .bottom) {
                if player.status != .reserved, let flag = player.countryFlag {
                    Text(flag).font(.system(size: 16)).offset(y: 6)
                }
            }

            Text(player.name)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurface)
                .lineLimit(1)
        }
        .frame(width: 56)
        .if(canEdit) { view in
            view
                .draggable(player)
                .dropDestination(for: AdminMatchPlayer.self) { dropped, _ in
                    guard let dragged = dropped.first, dragged.id != player.id else { return false }
                    Task { await viewModel.movePlayer(dragged, toTeam: team, swappingWith: player) }
                    return true
                } isTargeted: { targeted in
                    highlightedDropId = targeted ? dropId : nil
                }
        }
    }

    private func playerAvatar(url: String?, size: CGFloat) -> some View {
        Group {
            if let urlString = url {
                FMRemoteImage(urlString: urlString) {
                    FMAvatar(image: nil, size: size)
                }
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                FMAvatar(image: nil, size: size)
            }
        }
    }

    // MARK: - Empty Slot

    private func emptySlot(team: String, index: Int) -> some View {
        let dropId = "empty-\(team)-\(index)"
        return VStack(spacing: 4) {
            Circle()
                .fill(FMColors.surfaceContainerHigh)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(highlightedDropId == dropId ? FMColors.primary : FMColors.outline)
                )
                .overlay(
                    Circle()
                        .stroke(FMColors.primary, lineWidth: 2)
                        .opacity(highlightedDropId == dropId ? 1 : 0)
                )
            Text(L10n.AdminMatchDetail.emptySlot)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.outline)
                .lineLimit(1)
        }
        .frame(width: 56)
        .if(canEdit) { view in
            view.dropDestination(for: AdminMatchPlayer.self) { dropped, _ in
                guard let dragged = dropped.first else { return false }
                Task { await viewModel.movePlayer(dragged, toTeam: team) }
                return true
            } isTargeted: { targeted in
                highlightedDropId = targeted ? dropId : nil
            }
        }
    }

    // MARK: - Skeleton Team Card

    private func skeletonTeamCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 4).fill(FMColors.surfaceContainerHigh).frame(width: 60, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(FMColors.surfaceContainerHigh).frame(width: 50, height: 12)
            }
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 4) {
                        Circle().fill(FMColors.surfaceContainerHigh).frame(width: 44, height: 44)
                        RoundedRectangle(cornerRadius: 3).fill(FMColors.surfaceContainerHigh).frame(width: 40, height: 10)
                    }
                    .frame(width: 56)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        .shimmer()
    }

    // MARK: - Field Details Section

    private func fieldDetailsSection(field: AdminFieldItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.AdminMatchDetail.fieldDetails)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            VStack(spacing: 0) {
                if let footwear = field.footwearType {
                    detailRow(label: L10n.AdminMatchDetail.shoeType, value: FieldAttributeDisplay.footwearTypeName(forCode: footwear))
                    Divider().padding(.horizontal, 16)
                }
                if let fType = field.fieldType {
                    detailRow(label: L10n.AdminMatchDetail.fieldType, value: FieldAttributeDisplay.fieldTypeName(forCode: fType))
                    Divider().padding(.horizontal, 16)
                }
                detailRow(
                    label: L10n.AdminMatchDetail.parking,
                    value: field.hasParking ? L10n.AdminMatchDetail.yes : L10n.AdminMatchDetail.no
                )
                if let extra = field.extraInfo {
                    Divider().padding(.horizontal, 16)
                    detailRow(label: L10n.AdminMatchDetail.extraInfo, value: extra)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Rules Section

    private func rulesSection(rules: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.AdminMatchDetail.rules)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").font(FMTypography.bodySmall).foregroundColor(FMColors.onSurface)
                        Text(rule)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

}
