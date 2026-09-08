import SwiftUI
import UIKit
import MapKit
import FMDesignSystem
import PersistenceFramework
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet
import Lottie

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

/// Formats the time remaining until paid registration opens, using a granularity
/// that shrinks as the match approaches:
/// `2 d 05 h 14 min` → `7 h 08 min 12 s` → `18 min 09 s` → `42 s`.
private func formattedJoinWindow(_ seconds: Int) -> String {
    let total = max(0, seconds)
    let days = total / 86_400
    let hours = (total % 86_400) / 3_600
    let minutes = (total % 3_600) / 60
    let secs = total % 60
    if days > 0 {
        return String(format: "%d d %02d h %02d min", days, hours, minutes)
    } else if hours > 0 {
        return String(format: "%d h %02d min %02d s", hours, minutes, secs)
    } else if minutes > 0 {
        return String(format: "%d min %02d s", minutes, secs)
    } else {
        return String(format: "%d s", secs)
    }
}

/// Match detail screen showing field image, lineup, field details, rules, and join CTA
struct MatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MatchDetailViewModel
    private var match: MatchItem { viewModel.match }
    private let currentUserId: String? = KeychainManager.shared.userId
    private let isDemoMode: Bool

    /// Player whose public profile is being shown (drives navigation).
    @State private var selectedPlayerId: String? = nil

    init(match: MatchItem, isDemoMode: Bool = false) {
        self.isDemoMode = isDemoMode
        let factory = PlayerDependencyFactory(isDemoMode: isDemoMode)
        self._viewModel = StateObject(wrappedValue: MatchDetailViewModel(
            initialMatch: match,
            fetchDetailUseCase: factory.makeFetchMatchDetailUseCase(),
            joinMatchUseCase: factory.makeJoinMatchUseCase(),
            pollPaymentStatusUseCase: factory.makePollPaymentStatusUseCase(),
            subscribePlayersUseCase: factory.makeSubscribeMatchPlayersUseCase(),
            cancelMatchUseCase: factory.makeCancelMatchUseCase(),
            leaveMatchUseCase: factory.makeLeaveMatchUseCase(),
            pendingPaymentStore: factory.makePendingPaymentStore(),
            fetchPendingPaymentUseCase: factory.makeFetchPendingMatchPaymentUseCase(),
            fetchFieldAttributeCatalogsUseCase: factory.makeFetchFieldAttributeCatalogsUseCase(),
            authorizeSensitiveActionUseCase: factory.makeAuthorizeSensitiveActionUseCase()
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
    @State private var showMapPicker = false
    @State private var showLeaveConfirm = false
    @State private var showLeaveNoRefund = false
    @State private var showLeaveSuccess = false
    /// Per-second tick written by `joinWindowTimer` purely to re-render the countdown.
    /// The displayed value reads `joinWindowRemaining` live, so it's always accurate.
    @State private var joinWindowSeconds: Int = 0
    @State private var joinWindowTimer: Timer? = nil
    /// True after the 5-min reservation expired locally but the backend hasn't
    /// yet removed the user from the team in Firebase. Hides the join button and
    /// shows the "reservation expired / processing cancellation" message.
    @State private var reservationExpired = false

    // MARK: - Payment State

    @State private var paymentSheet: PaymentSheet?
    @State private var paymentError: String?
    @State private var shouldPresentPayment = false
    @State private var showPaymentSuccess = false
    @State private var showPaymentReusedToast = false
    @State private var showErrorOverlay = false
    /// API-provided title/message for the error overlay. `nil` falls back to generic copy.
    @State private var overlayErrorTitle: String?
    @State private var overlayErrorMessage: String?
    /// Triggers the pending payment issue alert (not recoverable or retry-later).
    @State private var showPendingPaymentIssue = false

    private var isCompletedMatch: Bool {
        match.matchStatus == .completed
    }

    private var isCanceledMatch: Bool {
        match.matchStatus == .canceled
    }

    private var isClosedMatch: Bool {
        isCompletedMatch || isCanceledMatch
    }

    /// Backend `MATCH_JOIN_PAYMENT_WINDOW_HOURS` — paid registration only opens this
    /// many hours before kickoff because Stripe won't hold a reservation any earlier.
    /// Mirrors the server default so the client hides the Join CTA until then.
    private static let joinPaymentWindowHours: Double = 120

    /// Instant paid registration opens: `startDate - joinPaymentWindowHours`.
    private var joinOpensAt: Date {
        match.startDate.addingTimeInterval(-Self.joinPaymentWindowHours * 3_600)
    }

    /// Live seconds remaining until paid registration opens (clamped at 0).
    private var joinWindowRemaining: Int {
        max(0, Int(joinOpensAt.timeIntervalSinceNow))
    }

    /// True while the match is still outside the paid-registration window. In this
    /// state the Join CTA and team join slots are hidden in favor of a countdown.
    private var isBeforeJoinWindow: Bool {
        !isClosedMatch && joinWindowRemaining > 0
    }

    private var completedGoalsBadgeColor: Color {
        Color(red: 0.42, green: 0.31, blue: 0.60)
    }

    /// Gold/amber accent for the MVP callout and top-scorer row — no equivalent
    /// token exists in `FMColors` today.
    private var mvpAccentColor: Color {
        Color(red: 0.83, green: 0.62, blue: 0.09)
    }

    private var mvpAccentBackground: Color {
        mvpAccentColor.opacity(0.12)
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
                        requestPaymentPresentation()
                    },
                    onPayLater: { confirmJoin() }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
            if showLeaveConfirm {
                FMConfirmationAlert(
                    icon: "xmark.circle.fill",
                    iconColor: FMColors.error,
                    iconBackgroundColor: FMColors.errorContainer,
                    title: L10n.MatchDetail.leaveMatchConfirmTitle,
                    message: L10n.MatchDetail.leaveMatchConfirmMessage,
                    primaryButtonTitle: L10n.MatchDetail.leaveMatchConfirm,
                    primaryButtonColor: FMColors.error,
                    secondaryButtonTitle: L10n.Common.cancel,
                    isLoading: viewModel.isLeaving,
                    onPrimaryAction: { Task { await viewModel.leaveMatch() } },
                    onSecondaryAction: { showLeaveConfirm = false }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
            if showLeaveNoRefund {
                FMConfirmationAlert(
                    icon: "info.circle.fill",
                    iconColor: FMColors.error,
                    iconBackgroundColor: FMColors.error.opacity(0.15),
                    title: L10n.MatchDetail.leaveNoRefundTitle,
                    message: L10n.MatchDetail.leaveNoRefundMessage,
                    primaryButtonTitle: L10n.MatchDetail.leaveNoRefundConfirm,
                    primaryButtonColor: FMColors.error,
                    secondaryButtonTitle: L10n.MatchDetail.leaveNoRefundCancel,
                    isLoading: viewModel.isLeaving,
                    onPrimaryAction: { Task { await viewModel.leaveMatch() } },
                    onSecondaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLeaveNoRefund = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
            if showLeaveSuccess {
                FMSuccessAlert(
                    title: L10n.MatchDetail.leaveSuccessTitle,
                    message: L10n.MatchDetail.leaveSuccessMessage,
                    buttonTitle: L10n.MatchDetail.leaveSuccessUnderstood,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLeaveSuccess = false
                        }
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(3)
            }
            if showPaymentSuccess {
                FMSuccessAlert(
                    title: L10n.Payment.successTitle,
                    message: L10n.Payment.successMessage,
                    buttonTitle: L10n.Payment.understood,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPaymentSuccess = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(3)
            }
            if showErrorOverlay {
                FMConfirmationAlert(
                    icon: "info.circle.fill",
                    iconColor: FMColors.error,
                    iconBackgroundColor: FMColors.error.opacity(0.15),
                    title: overlayErrorTitle ?? L10n.ErrorOverlay.title,
                    message: overlayErrorMessage ?? L10n.ErrorOverlay.message,
                    primaryButtonTitle: L10n.ErrorOverlay.understood,
                    primaryButtonColor: FMColors.primary,
                    secondaryButtonTitle: nil,
                    onPrimaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showErrorOverlay = false
                        }
                        overlayErrorTitle = nil
                        overlayErrorMessage = nil
                    },
                    onSecondaryAction: nil
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(4)
            }
            if viewModel.isPollingPayment {
                // Confirming payment — NOT joining (the user is already reserved).
                FMLoaderAlert(message: L10n.Payment.confirming)
                    .transition(.opacity)
                    .zIndex(5)
            } else if viewModel.isJoining {
                FMLoaderAlert(message: L10n.MatchDetail.joiningMatch)
                    .transition(.opacity)
                    .zIndex(5)
            }
            if showPendingPaymentIssue, let issue = viewModel.pendingPaymentIssue {
                switch issue {
                case .notRecoverable(let message):
                    FMConfirmationAlert(
                        icon: "exclamationmark.circle.fill",
                        iconColor: FMColors.error,
                        iconBackgroundColor: FMColors.errorContainer,
                        title: L10n.PendingPayment.notRecoverableTitle,
                        message: message,
                        primaryButtonTitle: L10n.MatchDetail.leaveMatch,
                        primaryButtonColor: FMColors.error,
                        secondaryButtonTitle: L10n.Common.ok,
                        isLoading: viewModel.isLeaving,
                        onPrimaryAction: {
                            Task { await viewModel.leaveMatch() }
                            showPendingPaymentIssue = false
                        },
                        onSecondaryAction: {
                            showPendingPaymentIssue = false
                            viewModel.clearPendingPaymentIssue()
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(6)

                case .retryLater(let message):
                    FMConfirmationAlert(
                        icon: "clock.fill",
                        iconColor: FMColors.primary,
                        iconBackgroundColor: FMColors.primary.opacity(0.15),
                        title: L10n.PendingPayment.retryLaterTitle,
                        message: message,
                        primaryButtonTitle: L10n.Common.retry,
                        primaryButtonColor: FMColors.primary,
                        secondaryButtonTitle: L10n.Common.ok,
                        isLoading: viewModel.isRecoveringPayment,
                        onPrimaryAction: {
                            showPendingPaymentIssue = false
                            viewModel.retryPendingPaymentRecovery()
                        },
                        onSecondaryAction: {
                            showPendingPaymentIssue = false
                            viewModel.clearPendingPaymentIssue()
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(6)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isJoining)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isPollingPayment)
        .onChange(of: viewModel.paymentDidSucceed) { succeeded in
            // Show the success overlay ONLY when payment polling confirmed success.
            // (Firestore-driven `isCurrentUserJoined` must not trigger this — otherwise
            // opening an already-joined match would pop the success message "out of nowhere".)
            guard succeeded else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showPaymentSuccess = true
            }
            viewModel.clearJoinData()
            viewModel.clearPaymentSuccess()
        }
        .onChange(of: viewModel.paymentConfirmationFailed) { failed in
            guard failed else { return }
            paymentError = L10n.Payment.confirmationError
            viewModel.clearPaymentConfirmationError()
        }
        .background(FMColors.background.ignoresSafeArea())
        // The hero image is full-bleed under the top safe area (`.ignoresSafeArea(.top)`).
        // A `ToolbarItem` back button forces the system nav bar to render, and its
        // background can stay opaque even with `.toolbarBackground(.hidden)` — the top
        // of the image ends up clipped by a solid strip (visible on iPhone 13 mini and
        // similar). Hiding the bar entirely and floating the button ourselves sidesteps
        // that system bar rendering altogether.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Hiding the nav bar above also disables iOS's native edge-swipe-to-go-back.
        // Applied before the button overlay below so the button stays on top and
        // fully tappable — the edge strip only wins hit-testing where the button isn't.
        .edgeSwipeToGoBack { dismiss() }
        .overlay(alignment: .topLeading) {
            FMBackButton(action: { dismiss() }, isStandalone: true)
                .padding(.leading, 16)
                .padding(.top, 8)
        }
        .modifier(HideTabBarModifier())
        .navigationDestination(isPresented: Binding(
            get: { selectedPlayerId != nil },
            set: { if !$0 { selectedPlayerId = nil } }
        )) {
            if let id = selectedPlayerId {
                PlayerProfileView(userId: id, isDemoMode: isDemoMode, originMatchId: match.id)
            }
        }
        .task { await viewModel.loadDetail() }
        .task { await viewModel.subscribeToPlayers() }
        .task { await viewModel.loadFieldAttributeCatalog() }
        .modifier(MatchDetailModifiers(view: self))
    }

    // MARK: - Alerts / Dialogs (extracted to reduce type-check complexity)

    fileprivate func applySharedModifiers<V: View>(_ view: V) -> some View {
        view
            .onChange(of: viewModel.joinData) { data in
                guard let data else { return }
                preparePaymentSheet(from: data)
            }
            .onChange(of: viewModel.paymentWasReused) { reused in
                guard reused else { return }
                showPaymentReusedToast = true
                viewModel.clearPaymentReused()
            }
            .fmToast(
                L10n.MatchDetail.paymentReusedNotice,
                isPresented: $showPaymentReusedToast,
                style: .success
            )
            .onChange(of: viewModel.currentUserReservedUntil) { expiryDate in
                guard let expiryDate, !hasJoined, viewModel.joinError == nil else { return }
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
            .onChange(of: viewModel.isCurrentUserInMatch) { inMatch in
                // Once the backend removes the expired reservation from Firebase,
                // clear the expired message so the user can join again.
                if !inMatch { reservationExpired = false }
            }
            .onAppear { startJoinWindowCountdown() }
            .onDisappear { stopJoinWindowCountdown() }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, hasJoined, let expiry = countdownExpiry else { return }
                let remaining = max(0, Int(expiry.timeIntervalSinceNow))
                countdownSeconds = remaining
                if remaining == 0 { cancelJoin() }
            }
            .onChange(of: scenePhase) { phase in
                // Re-sync the join-window countdown across background/foreground so the
                // timer doesn't drift while suspended.
                if phase == .active { startJoinWindowCountdown() } else { stopJoinWindowCountdown() }
            }
            .onChange(of: paymentError) { error in
                guard error != nil else { return }
                paymentError = nil
                withAnimation(.easeInOut(duration: 0.25)) {
                    showErrorOverlay = true
                }
            }
            .fmToast(
                viewModel.detailError ?? L10n.ErrorOverlay.refreshMessage,
                isPresented: Binding(
                    get: { viewModel.detailError != nil },
                    set: { if !$0 { viewModel.detailError = nil } }
                ),
                style: .error
            )
            .onChange(of: viewModel.joinError) { error in
                guard error != nil else { return }
                // Reset all join state — the API call failed so there is no reservation
                countdownTimer?.invalidate()
                countdownTimer = nil
                countdownExpiry = nil
                pendingTeam = nil
                paymentSheet = nil
                // Capture the API-provided error text before clearing VM state so the overlay can show it.
                overlayErrorTitle = viewModel.joinErrorTitle
                overlayErrorMessage = viewModel.joinError
                viewModel.clearJoinData()
                viewModel.clearJoinError()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showJoinOverlay = false
                    hasJoined = false
                    reservationExpired = false
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
            .onChange(of: viewModel.pendingPaymentIssue) { issue in
                // Follows the issue in both directions: the VM clears it as soon as the
                // reservation is released, and the alert must come down with it.
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPendingPaymentIssue = issue != nil
                }
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
                goalsSummarySection
                if !isClosedMatch {
                    fieldDetailsSection
                    rulesSection
                        .padding(.bottom, 16)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isClosedMatch {
                bottomBar
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Field image — FMRemoteImage seeds from the shared cache
            // synchronously, so it never flashes back to the default when
            // loadDetail() refreshes `match` with the same URL.
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
                
                locationRow
            }
            .padding(20)
        }
    }

    // MARK: - Location Row

    /// Venue address. When the backend supplies coordinates, the row becomes a
    /// button that shows a map picker (Apple Maps / Google Maps); otherwise plain text.
    @ViewBuilder
    private var locationRow: some View {
        if match.coordinate != nil {
            Button {
                showMapPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    Text(match.location)
                        .font(FMTypography.bodySmall)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .confirmationDialog(L10n.MatchDetail.openInMapsTitle, isPresented: $showMapPicker, titleVisibility: .visible) {
                Button(L10n.MatchDetail.openAppleMaps) {
                    openInAppleMaps()
                }
                if let coordinate = match.coordinate, isGoogleMapsInstalled {
                    Button(L10n.MatchDetail.openGoogleMaps) {
                        openInGoogleMaps(coordinate: coordinate)
                    }
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                Text(match.location)
                    .font(FMTypography.bodySmall)
            }
            .foregroundColor(.white.opacity(0.9))
        }
    }

    private var isGoogleMapsInstalled: Bool {
        UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
    }

    private func openInAppleMaps() {
        guard let coordinate = match.coordinate else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = match.venueName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate)
        ])
    }

    private func openInGoogleMaps(coordinate: CLLocationCoordinate2D) {
        let urlString = "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)&center=\(coordinate.latitude),\(coordinate.longitude)&zoom=16"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
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
                    Text(L10n.MatchStatus.canceled)
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

                        Text(L10n.MatchDetail.spotsLeft(liveSpotsLeft))
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
                        .foregroundColor(FMColors.onTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(FMColors.tertiary))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    /// Spots remaining, derived from the live Firestore roster so the badge
    /// tracks joins/leaves while the screen stays open. Falls back to the REST
    /// snapshot until the first Firestore snapshot arrives.
    private var liveSpotsLeft: Int {
        guard let liveA = viewModel.liveTeamAPlayers,
              let liveB = viewModel.liveTeamBPlayers else { return match.spotsLeft }
        return max(0, (match.teamAMax + match.teamBMax) - (liveA.count + liveB.count))
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
        // `max(..., count)` guards a degraded MatchItem (e.g. the one built by
        // HomeSuggestedMatchDTO) before loadDetail() brings the real capacity.
        let maxA = max(match.teamAMax, liveA.count)
        let maxB = max(match.teamBMax, liveB.count)
        return VStack(alignment: .leading, spacing: 16) {
            Text(lineupTitle)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            if hasError {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FMColors.error)
                        Text(L10n.MatchDetail.playersLoadError)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                        Spacer()
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.errorContainer))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.error.opacity(0.3), lineWidth: 1))
            } else if isLoading {
                skeletonTeamCard(name: L10n.Matches.teamA)
                skeletonTeamCard(name: L10n.Matches.teamB)
            } else {
                // Team A
                teamLineup(
                    name: L10n.Matches.teamA,
                    players: liveA,
                    maxPlayers: maxA,
                    team: .teamA
                )

                // Team B
                teamLineup(
                    name: L10n.Matches.teamB,
                    players: liveB,
                    maxPlayers: maxB,
                    team: .teamB
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var lineupTitle: String {
        if isCompletedMatch { return L10n.MatchStatus.completed }
        if isCanceledMatch { return L10n.MatchStatus.canceled }
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
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                // Join slot always first — hidden for finished/canceled matches, once
                // joined, or while the match is still outside the join window.
                // Kept outside the ScrollView so it stays fixed in place while the
                // player/empty slots scroll beside it.
                if !isCompletedMatch && !isCanceledMatch && !isBeforeJoinWindow {
                    joinSlot(for: team)
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
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Goals Summary Section

    @ViewBuilder
    private var goalsSummarySection: some View {
        if isCompletedMatch, let goalBreakdown = match.goalBreakdown {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "soccerball")
                            .font(.system(size: 20))
                            .foregroundColor(FMColors.primary)
                        Text(L10n.MatchDetail.goalsSummaryTitle)
                            .font(FMTypography.titleLarge)
                            .foregroundColor(FMColors.onBackground)
                    }
                    Text(L10n.MatchDetail.goalsSummarySubtitle)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .textCase(.uppercase)
                }

                if let teamAScore = match.teamAScore, let teamBScore = match.teamBScore {
                    scoreCard(teamAScore: teamAScore, teamBScore: teamBScore)
                }

                if let bestPlayer = match.bestPlayer {
                    bestPlayerCard(name: bestPlayer.name)
                }

                teamGoalsCard(name: L10n.Matches.teamA, total: match.teamAScore ?? 0, breakdown: goalBreakdown.teamA)
                teamGoalsCard(name: L10n.Matches.teamB, total: match.teamBScore ?? 0, breakdown: goalBreakdown.teamB)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func scoreCard(teamAScore: Int, teamBScore: Int) -> some View {
        HStack {
            VStack(spacing: 4) {
                Text(L10n.Matches.teamA)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text("\(teamAScore)")
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
            }
            .frame(maxWidth: .infinity)

            Text("—")
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onSurfaceVariant)

            VStack(spacing: 4) {
                Text(L10n.Matches.teamB)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text("\(teamBScore)")
                    .font(FMTypography.headlineMedium)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    private func bestPlayerCard(name: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundColor(mvpAccentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.MatchDetail.bestPlayer)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(mvpAccentColor)
                Text(name)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(mvpAccentBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(mvpAccentColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func teamGoalsCard(name: String, total: Int, breakdown: MatchTeamGoalBreakdown) -> some View {
        let sortedGoals = breakdown.playerGoals.sorted { $0.goals > $1.goals }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onBackground)
                Spacer()
                Text("\(total)")
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)
                    .bold()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 0) {
                ForEach(Array(sortedGoals.enumerated()), id: \.element.id) { index, playerGoal in
                    playerGoalRow(
                        name: playerGoal.name,
                        goals: playerGoal.goals,
                        isTopScorer: index == 0 && playerGoal.goals > 0,
                        rowIndex: index
                    )
                }

                if breakdown.externalGoals > 0 {
                    playerGoalRow(
                        name: L10n.MatchDetail.externalGoals,
                        goals: breakdown.externalGoals,
                        isTopScorer: false,
                        rowIndex: sortedGoals.count
                    )
                }
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

    private func playerGoalRow(name: String, goals: Int, isTopScorer: Bool, rowIndex: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "soccerball")
                .font(.system(size: 14))
                .foregroundColor(isTopScorer ? mvpAccentColor : FMColors.onSurfaceVariant)

            Text(name)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurface)

            Spacer()

            Text("\(goals)")
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.onSurface)
                .bold()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground(isTopScorer: isTopScorer, rowIndex: rowIndex))
    }

    private func rowBackground(isTopScorer: Bool, rowIndex: Int) -> Color {
        if isTopScorer { return mvpAccentBackground }
        return rowIndex % 2 == 0 ? .clear : FMColors.surfaceContainerHigh
    }

    // MARK: - Player Slot
    
    private func playerSlot(player: MatchPlayer) -> some View {
        let isCurrentUser = player.playerId == currentUserId
        let isReserved = player.status == .reserved
        let otherReserved = !isCurrentUser && isReserved
        let currentUserReserved = isCurrentUser && isReserved
        // Tappable for any non-reserved, identified player, including the current user → opens their profile.
        let canOpenProfile = !isReserved && !player.playerId.isEmpty

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
            .overlay(alignment: .bottom) {
                if !isReserved, let flag = player.countryFlag {
                    flagBadge(flag)
                }
            }

            Text(isReserved ? L10n.MatchDetail.reserved : player.name)
                .font(FMTypography.labelSmall)
                .foregroundColor(isReserved ? FMColors.primary : FMColors.onSurface)
                .lineLimit(1)
        }
        .frame(width: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canOpenProfile else { return }
            selectedPlayerId = player.playerId
        }
    }

    /// Flag badge anchored to the bottom of a player's avatar.
    private func flagBadge(_ flag: String) -> some View {
        Text(flag)
            .font(.system(size: 16))
            .offset(y: 6)
    }

    private func playerAvatar(url: String?, image: Image?, size: CGFloat) -> some View {
        Group {
            if let urlString = url {
                FMRemoteImage(urlString: urlString) {
                    FMAvatar(image: nil, size: size)
                }
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                FMAvatar(image: image, size: size)
            }
        }
    }
    
    // MARK: - Join Slot

    private func joinSlot(for team: JoinTeam) -> some View {
        // Hide the join slot once the current user is in the match (reserved or joined)
        guard !viewModel.isCurrentUserInMatch else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(spacing: 4) {
                Circle()
                    .stroke(FMColors.onSurface, lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(FMColors.onSurface)
                    )

                Text(L10n.MatchDetail.joinSlot)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurface)
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
                if !viewModel.shoeTypeDisplay.isEmpty {
                    detailRow(label: L10n.MatchDetail.shoeType, value: viewModel.shoeTypeDisplay)
                    Divider().padding(.horizontal, 16)
                }

                if !viewModel.fieldTypeDisplay.isEmpty {
                    detailRow(label: L10n.MatchDetail.fieldType, value: viewModel.fieldTypeDisplay)
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
                    Text(rule)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        Group {
            if viewModel.isCurrentUserJoined {
                // JOINED: sticky Leave match button with gradient scrim
                FMStickyActionBar(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: L10n.MatchDetail.leaveMatch,
                    isLoading: viewModel.isLeaving,
                    buttonColor: FMColors.error,
                    buttonTextColor: FMColors.onError,
                    action: { requestLeave() }
                )

            } else if hasJoined {
                // RESERVED: countdown + pay bar
                VStack(spacing: 0) {
                    Divider()
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
                        if paymentSheet != nil {
                            Button {
                                requestPaymentPresentation()
                            } label: {
                                payButtonLabel
                            }
                            .disabled(viewModel.isVerifyingPaymentSecurity)
                        } else {
                            payButtonLabel
                                .opacity(0.5)
                                .disabled(true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(FMColors.background, ignoresSafeAreaEdges: .bottom)

            } else if reservationExpired && viewModel.isCurrentUserInMatch {
                // Reservation expired — backend still processing cancellation
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 6) {
                        Text(L10n.MatchDetail.reservationExpiredTitle)
                            .font(FMTypography.labelLarge)
                            .foregroundColor(FMColors.onSurface)
                            .multilineTextAlignment(.center)
                        Text(L10n.MatchDetail.reservationExpiredMessage)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(FMColors.background, ignoresSafeAreaEdges: .bottom)

            } else if isBeforeJoinWindow {
                // BEFORE JOIN WINDOW: no CTA — only a countdown until registration opens
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 6) {
                        Text(L10n.MatchDetail.joinOpensCountdown(formattedJoinWindow(joinWindowRemaining)))
                            .font(FMTypography.labelLarge)
                            .foregroundColor(FMColors.onSurface)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                        Text(L10n.MatchDetail.joinNotOpenMessage)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(FMColors.background, ignoresSafeAreaEdges: .bottom)

            } else {
                // NOT joined: sticky join button with gradient scrim
                FMStickyActionBar(
                    icon: "person.2.fill",
                    title: L10n.MatchDetail.joinMatch,
                    isLoading: viewModel.isJoining,
                    action: { triggerJoin(team: .auto) }
                )
            }
        }
    }

    // MARK: - Join Actions

    private func triggerJoin(team: JoinTeam) {
        guard !isClosedMatch else { return }
        let resolved: JoinTeam
        if team == .auto {
            // Balance against the live roster — the REST arrays are frozen at
            // screen entry and can point the user at the team that just filled up.
            let a = viewModel.liveTeamAPlayers ?? match.teamAPlayers
            let b = viewModel.liveTeamBPlayers ?? match.teamBPlayers
            resolved = a.count <= b.count ? .teamA : .teamB
        } else {
            resolved = team
        }
        pendingTeam = resolved
        // Send nil when auto so the server assigns the team automatically
        let teamString: String? = team == .auto ? nil : (resolved == .teamA ? "A" : "B")

        Task {
            await viewModel.joinMatch(team: teamString)
            guard viewModel.joinError == nil, let data = viewModel.joinData else { return }
            guard !data.reusedExistingPayment else { return }
            let ttlSeconds = data.reservationTtlMs / 1000
            countdownExpiry = Date().addingTimeInterval(Double(ttlSeconds))
            countdownSeconds = ttlSeconds
            hasJoined = true
            reservationExpired = false
            withAnimation(.easeInOut(duration: 0.25)) {
                showJoinOverlay = true
            }
            startCountdown()
        }
    }

    /// Starts (or restarts) the ticking countdown shown while the match is outside the
    /// join window. No-ops once registration is already open, so the next body eval
    /// falls through to the normal Join CTA.
    private func startJoinWindowCountdown() {
        joinWindowTimer?.invalidate()
        joinWindowTimer = nil
        let remaining = Int(joinOpensAt.timeIntervalSinceNow)
        guard remaining > 0 else {
            joinWindowSeconds = 0
            return
        }
        joinWindowSeconds = remaining
        joinWindowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let secondsLeft = max(0, Int(joinOpensAt.timeIntervalSinceNow))
            joinWindowSeconds = secondsLeft
            if secondsLeft == 0 {
                joinWindowTimer?.invalidate()
                joinWindowTimer = nil
            }
        }
    }

    private func stopJoinWindowCountdown() {
        joinWindowTimer?.invalidate()
        joinWindowTimer = nil
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

    /// Reservation countdown reached 0 without payment — reset the join state and
    /// show the "reservation expired / processing cancellation" message until the
    /// backend removes the user from the team in Firebase.
    private func cancelJoin() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownExpiry = nil
        pendingTeam = nil
        paymentSheet = nil
        viewModel.clearJoinData()
        // The reservation is over — take down any payment-recovery dialog immediately
        // instead of waiting for the backend to drop the user from Firestore.
        viewModel.clearPendingPaymentIssue()
        withAnimation(.easeInOut(duration: 0.25)) {
            showJoinOverlay = false
            hasJoined = false
            // Only show the expired message if the user is still reserved in
            // Firebase; otherwise they can simply rejoin.
            reservationExpired = viewModel.isCurrentUserInMatch
        }
    }

    // MARK: - Payment

    private var payButtonLabel: some View {
        ZStack {
            if viewModel.isRecoveringPayment || viewModel.isVerifyingPaymentSecurity {
                ProgressView().tint(FMColors.onPrimary)
            } else {
                Text(L10n.JoinAlert.pay)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(minWidth: 44, minHeight: 36)
        .background(
            Capsule()
                .fill(FMColors.primary)
        )
    }

    /// Runs the payment-security gate, then — only if authorized — flips
    /// `shouldPresentPayment`, which the existing `.onChange(of: shouldPresentPayment)`
    /// handler uses to find the topmost view controller and call
    /// `sheet.present(from:completion:)`. A declined gate is a silent no-op: no
    /// toast, no overlay, `paymentSheet`/`hasJoined`/`showJoinOverlay` untouched —
    /// identical in spirit to the existing `.canceled` branch in `handlePaymentResult`.
    private func requestPaymentPresentation() {
        Task {
            guard await viewModel.authorizePayment() else { return }
            shouldPresentPayment = true
        }
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
        guard let clientSecret = data.clientSecret,
              let publishableKey = data.publishableKey,
              let customer = data.customer,
              let customerSessionClientSecret = data.customerSessionClientSecret else { return }
        STPAPIClient.shared.publishableKey = publishableKey
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "FutMatch"
        // Attach the customer so saved payment methods are shown in the sheet.
        // The backend returns a CustomerSession client secret (cuss_…), NOT an
        // ephemeral key — so it must go through the CustomerSession initializer.
        config.customer = .init(
            id: customer,
            customerSessionClientSecret: customerSessionClientSecret
        )
        paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: config
        )
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Stripe reported the payment as completed on the client side.
            // Stop the reservation countdown and dismiss the join overlay, then
            // poll the backend to get the authoritative payment status.
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownExpiry = nil
            paymentSheet = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                showJoinOverlay = false
                hasJoined = false
            }
            Task { await viewModel.confirmPaymentViaPolling() }
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



// MARK: - Join Confirmation Overlay

private struct JoinConfirmationOverlay: View {
    let countdownSeconds: Int
    let onPayNow: () -> Void
    let onPayLater: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var animationName: String {
        colorScheme == .dark ? "success_dark" : "success"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps behind card */ }

            VStack(spacing: 0) {
                // Lottie animation
                LottieView(animation: .named(animationName, bundle: .module))
                    .playing(loopMode: .playOnce)
                    .resizable()
                    .frame(width: 140, height: 140)
                    .padding(.top, 12)
                    .padding(.bottom, 0)

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
