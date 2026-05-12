import SwiftUI
import UIKit
import FMDesignSystem
import PersistenceFramework
import StripePaymentSheet

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ]),
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
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
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

// MARK: - JoinTeam

private enum JoinTeam {
    case teamA
    case teamB
    case auto
}

// MARK: - Countdown Formatting

private func formattedCountdown(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d", minutes, secs)
}

/// Match detail screen showing field image, lineup, field details, rules, and join CTA
struct MatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MatchDetailViewModel
    private var match: MatchItem { viewModel.match }
    private let currentUserId: String? = KeychainManager.shared.userId

    init(match: MatchItem) {
        let factory = HomeDependencyFactory()
        self._viewModel = StateObject(wrappedValue: MatchDetailViewModel(
            initialMatch: match,
            fetchDetailUseCase: factory.makeFetchMatchDetailUseCase(),
            joinMatchUseCase: factory.makeJoinMatchUseCase(),
            subscribePlayersUseCase: factory.makeSubscribeMatchPlayersUseCase(),
            cancelMatchUseCase: factory.makeCancelMatchUseCase(),
            leaveMatchUseCase: factory.makeLeaveMatchUseCase()
        ))
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Join State

    @State private var showJoinOverlay = false
    @State private var hasJoined = false
    @State private var pendingTeam: JoinTeam? = nil
    @State private var countdownSeconds: Int = 300
    /// Absolute expiry date — source of truth for the countdown, survives background.
    @State private var countdownExpiry: Date? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var showLeaveConfirm = false
    @State private var showLeaveNoRefund = false
    @State private var showLeaveSuccess = false

    // MARK: - Payment State

    @State private var paymentSheet: PaymentSheet?
    @State private var paymentError: String?
    @State private var shouldPresentPayment = false
    @State private var showPaymentSuccess = false
    @State private var showErrorOverlay = false

    private var normalizedMatchStatus: String {
        match.matchStatus.uppercased()
    }

    private var isCompletedMatch: Bool {
        normalizedMatchStatus == "COMPLETED"
    }

    private var isCanceledMatch: Bool {
        normalizedMatchStatus == "CANCELED" || normalizedMatchStatus == "CANCELLED"
    }

    private var isClosedMatch: Bool {
        isCompletedMatch || isCanceledMatch
    }

    private var completedGoalsBadgeColor: Color {
        Color(red: 0.42, green: 0.31, blue: 0.60)
    }

    private var winnerBadgeText: String? {
        guard isCompletedMatch else { return nil }

        if let winnerTeam = match.winnerTeam?.uppercased() {
            if winnerTeam == "A" || winnerTeam == "TEAM_A" || winnerTeam == "TEAMA" {
                return "Equipo A Gano"
            }
            if winnerTeam == "B" || winnerTeam == "TEAM_B" || winnerTeam == "TEAMB" {
                return "Equipo B Gano"
            }
        }

        guard let teamAScore = match.teamAScore, let teamBScore = match.teamBScore else {
            return nil
        }

        if teamAScore > teamBScore { return "Equipo A Gano" }
        if teamBScore > teamAScore { return "Equipo B Gano" }
        return "Empate"
    }

    private func goalsText(for team: JoinTeam) -> String? {
        guard isCompletedMatch else { return nil }
        let score: Int?
        switch team {
        case .teamA:
            score = match.teamAScore
        case .teamB:
            score = match.teamBScore
        case .auto:
            score = nil
        }

        guard let score else { return nil }
        return score == 1 ? "1 Gol" : "\(score) Goles"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            content
            if showJoinOverlay {
                JoinConfirmationOverlay(
                    countdownSeconds: countdownSeconds,
                    onPayNow: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showJoinOverlay = false
                        }
                        shouldPresentPayment = true
                    },
                    onPayLater: { confirmJoin() }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
            if showLeaveConfirm {
                LeaveConfirmationOverlay(
                    isLeaving: viewModel.isLeaving,
                    onConfirm: { Task { await viewModel.leaveMatch() } },
                    onCancel: { showLeaveConfirm = false }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
            if showLeaveNoRefund {
                LeaveNoRefundOverlay(
                    isLeaving: viewModel.isLeaving,
                    onConfirm: { Task { await viewModel.leaveMatch() } },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLeaveNoRefund = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
            if showLeaveSuccess {
                LeaveSuccessOverlay(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showLeaveSuccess = false
                    }
                    dismiss()
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(3)
            }
            if showPaymentSuccess {
                PaymentSuccessOverlay(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showPaymentSuccess = false
                    }
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(3)
            }
            if showErrorOverlay {
                MatchErrorOverlay(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showErrorOverlay = false
                    }
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(4)
            }
            if viewModel.isJoining {
                SoccerBallLoaderOverlay()
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isJoining)
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                }
            }
        }
        .modifier(HideTabBarModifier())
        .task { await viewModel.loadDetail() }
        .task { await viewModel.subscribeToPlayers() }
        .modifier(MatchDetailModifiers(view: self))
    }

    // MARK: - Alerts / Dialogs (extracted to reduce type-check complexity)

    fileprivate func applySharedModifiers<V: View>(_ view: V) -> some View {
        view
            .onChange(of: viewModel.joinData) { data in
                guard let data else { return }
                preparePaymentSheet(from: data)
            }
            .onChange(of: viewModel.currentUserReservedUntil) { expiryDate in
                guard let expiryDate, !hasJoined else { return }
                let remaining = Int(expiryDate.timeIntervalSinceNow)
                guard remaining > 0 else { return }
                countdownExpiry = expiryDate
                countdownSeconds = remaining
                hasJoined = true
                startCountdown()
            }
            .onChange(of: viewModel.matchLeft) { left in
                guard left else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLeaveConfirm = false
                    showLeaveNoRefund = false
                    showLeaveSuccess = true
                }
            }
            .onChange(of: viewModel.matchCancelled) { cancelled in
                guard cancelled else { return }
                dismiss()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, hasJoined, let expiry = countdownExpiry else { return }
                let remaining = max(0, Int(expiry.timeIntervalSinceNow))
                countdownSeconds = remaining
                if remaining == 0 { cancelJoin() }
            }
            .onChange(of: paymentError) { error in
                guard error != nil else { return }
                paymentError = nil
                withAnimation(.easeInOut(duration: 0.25)) {
                    showErrorOverlay = true
                }
            }
            .alert(L10n.MatchDetail.loadError, isPresented: Binding(
                get: { viewModel.detailError != nil },
                set: { _ in }
            )) {
                Button(L10n.Common.retry) { Task { await viewModel.loadDetail() } }
                Button(L10n.Common.cancel, role: .cancel) { }
            } message: {
                Text(viewModel.detailError ?? "")
            }
            .onChange(of: viewModel.joinError) { error in
                guard error != nil else { return }
                viewModel.clearJoinError()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showErrorOverlay = true
                }
            }
            .alert(L10n.MatchDetail.leaveMatchError, isPresented: Binding(
                get: { viewModel.leaveError != nil },
                set: { _ in viewModel.clearLeaveError() }
            )) {
                Button(L10n.Common.ok, role: .cancel) { }
            } message: {
                Text(viewModel.leaveError ?? "")
            }
            .onChange(of: shouldPresentPayment) { present in
                guard present, let sheet = paymentSheet else {
                    shouldPresentPayment = false
                    return
                }
                shouldPresentPayment = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard let vc = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .flatMap(\.windows)
                        .first(where: \.isKeyWindow)?
                        .rootViewController else { return }
                    // Walk to the topmost presented controller
                    var top = vc
                    while let presented = top.presentedViewController { top = presented }
                    sheet.present(from: top, completion: handlePaymentResult)
                }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                infoBar
                lineupSection
                if !isClosedMatch {
                    fieldDetailsSection
                    rulesSection
                        .padding(.bottom, 16)
                    bottomBar
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Field image
            Group {
                if let urlString = match.fieldImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image("defaultField", bundle: .main)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                } else {
                    Image("defaultField", bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
            
            // Venue name + badge
            VStack(alignment: .leading, spacing: 8) {
                // Match type badge
                Text(match.matchType)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(FMColors.primary)
                    )
                
                Text(match.venueName)
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(.white)
                    .bold()
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    Text(match.location)
                        .font(FMTypography.bodySmall)
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
        }
    }
    
    // MARK: - Info Bar (Date, Price, Duration, Spots)
    
    private var infoBar: some View {
        VStack(spacing: 12) {
            HStack {
                // Date + Time
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    
                    Text("\(match.date) - \(match.timeRange)")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurface)
                }
                
                Spacer()
                
                // Price
                Text(match.price)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
            }
            
            HStack {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    
                    Text(match.duration)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                
                Spacer()
                
                if isCanceledMatch {
                    Text("Cancelado")
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(FMColors.error.opacity(0.15))
                        )
                } else if !isCompletedMatch {
                    // Spots left badge
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))

                        Text(L10n.MatchDetail.spotsLeft(match.spotsLeft))
                            .font(FMTypography.labelSmall)
                    }
                    .foregroundColor(FMColors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(FMColors.primaryContainer)
                    )
                }

                if let winnerText = winnerBadgeText {
                    Text(winnerText)
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(FMColors.primaryContainer)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            FMColors.surfaceContainerLowest
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
    
    // MARK: - Lineup Section
    
    private var lineupSection: some View {
        let isLoading = viewModel.liveTeamAPlayers == nil || viewModel.liveTeamBPlayers == nil
        let liveA = viewModel.liveTeamAPlayers ?? []
        let liveB = viewModel.liveTeamBPlayers ?? []
        let perTeamMax = max(1, (match.spotsLeft + liveA.count + liveB.count) / 2)
        return VStack(alignment: .leading, spacing: 16) {
            Text(lineupTitle)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            if isLoading {
                skeletonTeamCard(name: L10n.Matches.teamA)
                skeletonTeamCard(name: L10n.Matches.teamB)
            } else {
                // Team A
                teamLineup(
                    name: L10n.Matches.teamA,
                    players: liveA,
                    maxPlayers: perTeamMax,
                    team: .teamA
                )
                
                // Team B
                teamLineup(
                    name: L10n.Matches.teamB,
                    players: liveB,
                    maxPlayers: perTeamMax,
                    team: .teamB
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var lineupTitle: String {
        if isCompletedMatch {
            return "Finalizado"
        }
        if isCanceledMatch {
            return "Cancelado"
        }
        return L10n.MatchDetail.currentLineup
    }

    // MARK: - Team Lineup Row
    
    private func teamLineup(name: String, players: [MatchPlayer], maxPlayers: Int, team: JoinTeam) -> some View {
        let emptyCount = max(0, maxPlayers - players.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text(name)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onBackground)

                    if let goalsLabel = goalsText(for: team) {
                        Text(goalsLabel)
                            .font(FMTypography.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(completedGoalsBadgeColor)
                            )
                    }
                }
                
                Spacer()
                
                Text(L10n.MatchDetail.playerCount(players.count, maxPlayers))
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Existing players (joined + reserved)
                    ForEach(players) { player in
                        playerSlot(player: player)
                    }
                    
                    // Empty slots to fill remaining capacity
                    ForEach(0..<emptyCount, id: \.self) { _ in
                        emptySlot
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
    
    // MARK: - Player Slot
    
    private func playerSlot(player: MatchPlayer) -> some View {
        let isCurrentUser = player.playerId == currentUserId
        let isReserved = player.status == .reserved
        let otherReserved = !isCurrentUser && isReserved
        let currentUserReserved = isCurrentUser && isReserved

        return VStack(spacing: 4) {
            ZStack {
                if otherReserved {
                    Circle()
                        .fill(FMColors.surfaceContainerHigh)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(FMColors.primary.opacity(0.6))
                        )
                        .overlay(
                            Circle()
                                .stroke(FMColors.primary, lineWidth: 2)
                                .padding(1)
                        )
                } else {
                    playerAvatar(url: player.avatarUrl, image: player.avatarImage, size: 44)
                        .overlay(
                            Group {
                                if currentUserReserved {
                                    Circle()
                                        .stroke(FMColors.primary, lineWidth: 2)
                                        .padding(1)
                                }
                            }
                        )
                }
            }

            Text(isReserved ? L10n.MatchDetail.reserved : player.name)
                .font(FMTypography.labelSmall)
                .foregroundColor(isReserved ? FMColors.primary : FMColors.onSurface)
                .lineLimit(1)
        }
        .frame(width: 56)
    }

    private func playerAvatar(url: String?, image: Image?, size: CGFloat) -> some View {
        Group {
            if let urlString = url, let avatarURL = URL(string: urlString) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let loaded):
                        loaded.resizable().scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    default:
                        FMAvatar(image: nil, size: size)
                    }
                }
            } else {
                FMAvatar(image: image, size: size)
            }
        }
    }
    
    // MARK: - Join Slot

    private func joinSlot(for team: JoinTeam) -> some View {
        // Hide the join slot once the current user holds a JOINED spot
        guard !viewModel.isCurrentUserJoined else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(spacing: 4) {
                Circle()
                    .stroke(FMColors.primary, style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(FMColors.primary)
                    )

                Text(L10n.MatchDetail.joinSlot)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.primary)
                    .lineLimit(1)
            }
            .frame(width: 56)
            .disabled(viewModel.isJoining)
            .onTapGesture {
                guard !viewModel.isJoining else { return }
                triggerJoin(team: team)
            }
        )
    }
    
    // MARK: - Empty Slot
    
    private var emptySlot: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(FMColors.surfaceContainerHigh)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FMColors.outline)
                )
            
            Text(L10n.MatchDetail.empty)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.outline)
                .lineLimit(1)
        }
        .frame(width: 56)
    }
    
    // MARK: - Skeleton Team Card
    
    private func skeletonTeamCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FMColors.surfaceContainerHigh)
                    .frame(width: 60, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(FMColors.surfaceContainerHigh)
                    .frame(width: 50, height: 12)
            }
            
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(FMColors.surfaceContainerHigh)
                            .frame(width: 44, height: 44)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(FMColors.surfaceContainerHigh)
                            .frame(width: 40, height: 10)
                    }
                    .frame(width: 56)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
        .shimmer()
    }
    
    // MARK: - Field Details Section
    
    private var fieldDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.MatchDetail.fieldDetails)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
            
            VStack(spacing: 0) {
                if !match.shoeType.isEmpty {
                    detailRow(label: L10n.MatchDetail.shoeType, value: match.shoeType)
                    Divider().padding(.horizontal, 16)
                }
                
                if !match.fieldType.isEmpty {
                    detailRow(label: L10n.MatchDetail.fieldType, value: match.fieldType)
                    Divider().padding(.horizontal, 16)
                }
                
                detailRow(
                    label: L10n.MatchDetail.parking,
                    value: match.hasParking ? L10n.MatchDetail.yes : L10n.MatchDetail.no
                )
                
                if let extraInfo = match.extraInfo {
                    Divider().padding(.horizontal, 16)
                    detailRow(label: L10n.MatchDetail.extraInfo, value: extraInfo)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Detail Row
    
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
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.MatchDetail.rules)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(match.rules.enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                        
                        Text(rule)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            if isClosedMatch {
                Text(isCompletedMatch ? "Partido finalizado" : "Partido cancelado")
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
            } else if viewModel.isCurrentUserJoined {
                // JOINED: show Leave match button
                Button {
                    requestLeave()
                } label: {
                    Group {
                        if viewModel.isLeaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: FMColors.onError))
                        } else {
                            Text(L10n.MatchDetail.leaveMatch)
                                .font(FMTypography.labelLarge)
                                .foregroundColor(FMColors.onError)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMColors.error.opacity(viewModel.isLeaving ? 0.7 : 1.0))
                    )
                }
                .disabled(viewModel.isLeaving)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else if hasJoined {
                // RESERVED: countdown + pay bar
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(FMColors.onSurfaceVariant)
                            Text(L10n.JoinAlert.countdown(formattedCountdown(countdownSeconds)))
                                .font(FMTypography.bodySmall)
                                .foregroundColor(FMColors.onSurface)
                                .monospacedDigit()
                        }
                        Button {
                            requestLeave()
                        } label: {
                            Text(L10n.MatchDetail.leaveMatch)
                                .font(FMTypography.labelSmall)
                                .foregroundColor(FMColors.error)
                        }
                        .disabled(viewModel.isLeaving)
                    }
                    Spacer()
                    if let sheet = paymentSheet {
                        PaymentSheet.PaymentButton(
                            paymentSheet: sheet,
                            onCompletion: handlePaymentResult
                        ) {
                            payButtonLabel
                        }
                    } else {
                        payButtonLabel
                            .opacity(0.5)
                            .disabled(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                // NOT joined: join button
                Button {
                    triggerJoin(team: .auto)
                } label: {
                    Text(L10n.MatchDetail.joinMatch)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .disabled(viewModel.isJoining)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(
            FMColors.background
                .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
        )
    }

    // MARK: - Join Actions

    private func triggerJoin(team: JoinTeam) {
        guard !isClosedMatch else { return }
        let resolved: JoinTeam
        if team == .auto {
            resolved = match.teamAPlayers.count <= match.teamBPlayers.count ? .teamA : .teamB
        } else {
            resolved = team
        }
        pendingTeam = resolved
        // Send nil when auto so the server assigns the team automatically
        let teamString: String? = team == .auto ? nil : (resolved == .teamA ? "A" : "B")

        Task {
            await viewModel.joinMatch(team: teamString)
            guard viewModel.joinError == nil, let data = viewModel.joinData else { return }
            let ttlSeconds = data.reservationTtlMs / 1000
            countdownExpiry = Date().addingTimeInterval(Double(ttlSeconds))
            countdownSeconds = ttlSeconds
            hasJoined = true
            withAnimation(.easeInOut(duration: 0.25)) {
                showJoinOverlay = true
            }
            startCountdown()
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let expiry = countdownExpiry else { return }
            let remaining = max(0, Int(expiry.timeIntervalSinceNow))
            countdownSeconds = remaining
            if remaining == 0 { cancelJoin() }
        }
    }

    /// User tapped "Continuar" — close overlay but keep countdown + pay bar.
    private func confirmJoin() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showJoinOverlay = false
        }
    }

    /// User tapped "Cancelar" — reset everything (reservation not yet paid).
    private func cancelJoin() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownExpiry = nil
        pendingTeam = nil
        paymentSheet = nil
        viewModel.clearJoinData()
        withAnimation(.easeInOut(duration: 0.25)) {
            showJoinOverlay = false
            hasJoined = false
        }
    }

    // MARK: - Payment

    private var payButtonLabel: some View {
        Text(L10n.JoinAlert.pay)
            .font(FMTypography.labelLarge)
            .foregroundColor(FMColors.onPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(FMColors.primary)
            )
    }

    private func requestLeave() {
        let hoursUntilMatch = match.startDate.timeIntervalSince(Date()) / 3600
        withAnimation(.easeInOut(duration: 0.25)) {
            if hoursUntilMatch < 6 {
                showLeaveNoRefund = true
            } else {
                showLeaveConfirm = true
            }
        }
    }

    private func preparePaymentSheet(from data: JoinMatchData) {
        STPAPIClient.shared.publishableKey = data.publishableKey
        #if !DEBUG
        STPAPIClient.shared.logLevel = .none
        #endif
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "FutMatch"
        paymentSheet = PaymentSheet(
            paymentIntentClientSecret: data.clientSecret,
            configuration: config
        )
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Clear payment/reservation state; stay in view.
            // Firestore will push isCurrentUserJoined = true which updates the UI.
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownExpiry = nil
            paymentSheet = nil
            viewModel.clearJoinData()
            withAnimation(.easeInOut(duration: 0.25)) {
                showJoinOverlay = false
                hasJoined = false
                showPaymentSuccess = true
            }
        case .canceled:
            break
        case .failed(let error):
            paymentError = error.localizedDescription
        }
    }
}

// MARK: - Shared Modifiers (extracted to reduce type-check complexity in body)

private struct MatchDetailModifiers: ViewModifier {
    let view: MatchDetailView

    func body(content: Content) -> some View {
        view.applySharedModifiers(content)
    }
}

// MARK: - Leave Confirmation Overlay

private struct LeaveConfirmationOverlay: View {
    let isLeaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            VStack(spacing: 0) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(FMColors.errorContainer)
                        .frame(width: 72, height: 72)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(FMColors.error)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.MatchDetail.leaveMatchConfirmTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.MatchDetail.leaveMatchConfirmMessage)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Confirm button
                Button(action: onConfirm) {
                    Group {
                        if isLeaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: FMColors.onError))
                        } else {
                            Text(L10n.MatchDetail.leaveMatchConfirm)
                                .font(FMTypography.labelLarge)
                                .foregroundColor(FMColors.onError)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMColors.error)
                    )
                }
                .disabled(isLeaving)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Cancel button
                Button(action: onCancel) {
                    Text(L10n.Common.cancel)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isLeaving)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Leave No Refund Overlay

private struct LeaveNoRefundOverlay: View {
    let isLeaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Info icon
                ZStack {
                    Circle()
                        .fill(FMColors.error.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(FMColors.error)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.MatchDetail.leaveNoRefundTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.MatchDetail.leaveNoRefundMessage)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Confirm leave without refund
                Button(action: onConfirm) {
                    Group {
                        if isLeaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: FMColors.onError))
                        } else {
                            Text(L10n.MatchDetail.leaveNoRefundConfirm)
                                .font(FMTypography.labelLarge)
                                .foregroundColor(FMColors.onError)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMColors.error)
                    )
                }
                .disabled(isLeaving)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Go back button
                Button(action: onCancel) {
                    Text(L10n.MatchDetail.leaveNoRefundCancel)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isLeaving)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Leave Success Overlay

private struct LeaveSuccessOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Checkmark icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.MatchDetail.leaveSuccessTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.MatchDetail.leaveSuccessMessage)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Understood button
                Button(action: onDismiss) {
                    Text(L10n.MatchDetail.leaveSuccessUnderstood)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Payment Success Overlay

private struct PaymentSuccessOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Checkmark icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.Payment.successTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.Payment.successMessage)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Understood button
                Button(action: onDismiss) {
                    Text(L10n.Payment.understood)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Error Overlay

private struct MatchErrorOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(FMColors.error.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(FMColors.error)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.ErrorOverlay.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.ErrorOverlay.message)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Understood button
                Button(action: onDismiss) {
                    Text(L10n.ErrorOverlay.understood)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Join Confirmation Overlay

private struct JoinConfirmationOverlay: View {
    let countdownSeconds: Int
    let onPayNow: () -> Void
    let onPayLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Checkmark icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Title
                Text(L10n.JoinAlert.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Message
                Text(L10n.JoinAlert.message)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // Countdown row
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    Text(L10n.JoinAlert.countdown(formattedCountdown(countdownSeconds)))
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurface)
                        .monospacedDigit()
                }
                .padding(.top, 16)

                // Pay now button
                Button(action: onPayNow) {
                    Text(L10n.JoinAlert.payNow)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FMColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Pay later button
                Button(action: onPayLater) {
                    Text(L10n.JoinAlert.payLater)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Soccer Ball Loader Overlay

private struct SoccerBallLoaderOverlay: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "soccerball")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                Text(L10n.MatchDetail.joiningMatch)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

#Preview {
    NavigationStack {
        MatchDetailView(
            match: MatchItem(
                venueName: "Roma 21",
                location: "CDMX, Roma Norte",
                timeRange: "19:50 PM - 20:50 PM",
                date: "Vie, 24 Mar",
                price: "$200.00 MXN",
                matchType: "Mixto",
                spotsLeft: 2,
                teamAPlayers: [
                    MatchPlayer(name: "Juan P."),
                    MatchPlayer(name: "Juan P."),
                    MatchPlayer(name: "Juan P."),
                    MatchPlayer(name: "Juan P.")
                ],
                teamBPlayers: [
                    MatchPlayer(name: "Sofía P."),
                    MatchPlayer(name: "Juan P.")
                ],
                teamAMax: 5,
                teamBMax: 5,
                distance: "1.4 km",
                duration: "60 min",
                shoeType: "Tacos para pasto sintético",
                fieldType: "Pasto sintético",
                hasParking: true,
                extraInfo: "El campo cuenta con vestidores, baños y área de descanso.",
                rules: [
                    "Llegar 15 minutos antes para organización de equipos.",
                    "Uso obligatorio de tenis o tacos para pasto sintético.",
                    "No se permite jugar con tachones metálicos.",
                    "Juego limpio y respeto entre jugadores.",
                    "En caso de faltas graves o conducta antideportiva, el organizador podrá retirar al jugador sin reembolso.",
                    "El partido inicia puntualmente a la hora indicada."
                ]
            )
        )
    }
}
