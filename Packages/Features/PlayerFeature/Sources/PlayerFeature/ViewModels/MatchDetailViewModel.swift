import Foundation
import PersistenceFramework
import AdminFeature

// MARK: - MatchDetailViewModel

@MainActor
final class MatchDetailViewModel: ObservableObject {
    @Published private(set) var match: MatchItem
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var fieldAttributeCatalog = FieldAttributeCatalog()
    /// Non-nil when detail load fails — shown as toast (data is always available from the list).
    @Published var detailError: String?

    // MARK: - Live Players State (Firestore — presence & reservation only)

    @Published private(set) var liveTeamAPlayers: [MatchPlayer]?
    @Published private(set) var liveTeamBPlayers: [MatchPlayer]?
    /// Non-nil when the current user has an active RESERVED slot — holds the expiry date.
    @Published private(set) var currentUserReservedUntil: Date?
    /// Non-nil when Firestore player stream fails.
    @Published var playersError: String?

    // MARK: - Join State

    @Published private(set) var isJoining = false
    @Published private(set) var joinError: String?
    /// API-provided error title for a failed join (e.g. "Inscripciones no abiertas").
    /// `nil` for non-API errors, so callers fall back to a generic title.
    @Published private(set) var joinErrorTitle: String?
    /// Set after a successful join call — holds the Stripe payment data.
    /// Also restored from Keychain when a reservation is found on app relaunch.
    @Published private(set) var joinData: JoinMatchData?

    // MARK: - Payment Poll State

    /// True while polling `GET /payment/poll/{matchId}` after Stripe reports success.
    @Published private(set) var isPollingPayment = false
    /// Set when polling ends with a non-success terminal state.
    @Published private(set) var paymentConfirmationFailed = false
    /// One-shot signal: becomes true ONLY when payment polling confirms success.
    /// Distinct from `isCurrentUserJoined` (which Firestore can set on screen load
    /// for an already-joined user) so the success overlay never fires "out of nowhere".
    @Published private(set) var paymentDidSucceed = false
    /// One-shot signal: true when the backend reused an existing confirmed payment
    /// so no Stripe sheet was needed. View reacts by showing an informational banner.
    @Published private(set) var paymentWasReused = false

    // MARK: - Pending Payment Recovery State (when local cache is missing)

    /// True while `GET /payment/matches/{matchId}/pending` is in flight.
    @Published private(set) var isRecoveringPayment = false
    /// Set when recovery fails in a user-facing way. Dialog fires on `.notRecoverable`,
    /// dialog with retry on `.retryLater`.
    @Published private(set) var pendingPaymentIssue: PendingPaymentIssue?
    /// Prevents multiple recovery attempts per reservation. Cleared when the
    /// reservation expires or is cancelled.
    private var hasAttemptedPendingRecovery = false

    // MARK: - Cancel State

    @Published private(set) var isCancelling = false
    @Published private(set) var cancelError: String?
    @Published private(set) var matchCancelled = false

    // MARK: - Leave / Joined State

    /// True when the backend has confirmed via polling that the payment succeeded.
    @Published private(set) var isCurrentUserJoined = false

    /// True when the current user is part of the match in any capacity (reserved or joined).
    var isCurrentUserInMatch: Bool {
        guard let userId = currentUserId() else { return false }
        let all = (liveTeamAPlayers ?? []) + (liveTeamBPlayers ?? [])
        return all.contains { $0.playerId == userId }
    }
    @Published private(set) var isLeaving = false
    @Published private(set) var leaveError: String?
    /// Becomes true after a successful leave — view should dismiss.
    @Published private(set) var matchLeft = false

    // MARK: - Dependencies

    private let fetchDetailUseCase: FetchMatchDetailUseCaseProtocol
    private let joinMatchUseCase: JoinMatchUseCaseProtocol
    private let pollPaymentStatusUseCase: PollPaymentStatusUseCaseProtocol
    private let subscribePlayersUseCase: SubscribeMatchPlayersUseCaseProtocol
    private let cancelMatchUseCase: CancelMatchUseCaseProtocol
    private let leaveMatchUseCase: LeaveMatchUseCaseProtocol
    private let pendingPaymentStore: PendingPaymentStoreProtocol
    private let fetchPendingPaymentUseCase: FetchPendingMatchPaymentUseCaseProtocol
    private let fetchFieldAttributeCatalogsUseCase: FetchFieldAttributeCatalogsUseCaseProtocol
    /// Resolves the signed-in user's id. Injected so the reservation and payment-recovery
    /// branches are testable without touching the real Keychain.
    private let currentUserId: () -> String?

    init(
        initialMatch: MatchItem,
        fetchDetailUseCase: FetchMatchDetailUseCaseProtocol,
        joinMatchUseCase: JoinMatchUseCaseProtocol,
        pollPaymentStatusUseCase: PollPaymentStatusUseCaseProtocol,
        subscribePlayersUseCase: SubscribeMatchPlayersUseCaseProtocol,
        cancelMatchUseCase: CancelMatchUseCaseProtocol,
        leaveMatchUseCase: LeaveMatchUseCaseProtocol,
        pendingPaymentStore: PendingPaymentStoreProtocol,
        fetchPendingPaymentUseCase: FetchPendingMatchPaymentUseCaseProtocol,
        fetchFieldAttributeCatalogsUseCase: FetchFieldAttributeCatalogsUseCaseProtocol,
        currentUserId: @escaping () -> String? = { KeychainManager.shared.userId }
    ) {
        self.match = initialMatch
        self.fetchDetailUseCase = fetchDetailUseCase
        self.joinMatchUseCase = joinMatchUseCase
        self.pollPaymentStatusUseCase = pollPaymentStatusUseCase
        self.subscribePlayersUseCase = subscribePlayersUseCase
        self.cancelMatchUseCase = cancelMatchUseCase
        self.leaveMatchUseCase = leaveMatchUseCase
        self.pendingPaymentStore = pendingPaymentStore
        self.fetchPendingPaymentUseCase = fetchPendingPaymentUseCase
        self.fetchFieldAttributeCatalogsUseCase = fetchFieldAttributeCatalogsUseCase
        self.currentUserId = currentUserId
    }

    // MARK: - Field Attribute Catalog

    var shoeTypeDisplay: String { fieldAttributeCatalog.footwearName(for: match.shoeType) }
    var fieldTypeDisplay: String { fieldAttributeCatalog.fieldTypeName(for: match.fieldType) }

    func loadFieldAttributeCatalog() async {
        let catalogs = await fetchFieldAttributeCatalogsUseCase.execute()
        fieldAttributeCatalog = FieldAttributeCatalog(catalogs: catalogs)
    }

    // MARK: - Load Detail

    func loadDetail() async {
        isLoadingDetail = true
        detailError = nil
        do {
            match = try await fetchDetailUseCase.execute(matchId: match.id)
        } catch {
            guard !error.isCancellation else {
                isLoadingDetail = false
                return
            }
            detailError = error.apiErrorMessage ?? error.localizedDescription
        }
        isLoadingDetail = false
    }

    // MARK: - Join

    /// Calls POST /match/{id}/join. `team` is "A", "B", or nil for auto-assign.
    func joinMatch(team: String?) async {
        isJoining = true
        joinError = nil
        do {
            let data = try await joinMatchUseCase.execute(matchId: match.id, team: team)
            if data.reusedExistingPayment {
                paymentWasReused = true
                isCurrentUserJoined = true
                clearJoinData()
                NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
            } else {
                joinData = data
                pendingPaymentStore.save(data, matchId: match.id)
                // The backend is already holding the spot at this point — the
                // user shows up in `/match/my-matches` as RESERVED even though
                // payment hasn't been captured yet. Without this the Home
                // next-match card and the Reserved tab stay stale until a
                // manual pull-to-refresh, because the Firestore observer below
                // only signals on the RESERVED → JOINED transition.
                NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
            }
        } catch {
            guard !error.isCancellation else {
                isJoining = false
                return
            }
            joinErrorTitle = error.apiErrorTitle
            joinError = error.apiErrorMessage ?? error.localizedDescription
            currentUserReservedUntil = nil
        }
        isJoining = false
    }

    /// Called by the view right after Stripe's PaymentSheet reports `.completed`.
    /// Polls `GET /payment/poll/{matchId}` until the backend confirms the payment
    /// is in a terminal state. This is the single source of truth for payment success.
    func confirmPaymentViaPolling() async {
        isPollingPayment = true
        paymentConfirmationFailed = false

        let result = await pollPaymentStatusUseCase.execute(matchId: match.id)

        isPollingPayment = false

        switch result {
        case .success:
            isCurrentUserJoined = true
            paymentDidSucceed = true
            clearJoinData()
            NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
        case .failure, .timeout:
            paymentConfirmationFailed = true
        }
    }

    func clearPaymentConfirmationError() {
        paymentConfirmationFailed = false
    }

    func clearPaymentSuccess() {
        paymentDidSucceed = false
    }

    func clearPaymentReused() {
        paymentWasReused = false
    }

    /// Clears in-memory and persisted join data (call after payment completes or reservation expires).
    func clearJoinData() {
        joinData = nil
        pendingPaymentStore.clear(matchId: match.id)
    }

    func clearJoinError() {
        joinError = nil
        joinErrorTitle = nil
    }

    func clearCancelError() {
        cancelError = nil
    }

    func clearLeaveError() {
        leaveError = nil
    }

    func clearPendingPaymentIssue() {
        pendingPaymentIssue = nil
    }

    func retryPendingPaymentRecovery() {
        pendingPaymentIssue = nil
        Task { await recoverPendingPayment() }
    }

    // MARK: - Pending Payment Recovery

    /// A reservation with less than this left is already dead for practical purposes:
    /// the user cannot complete a Stripe payment in what remains, and the backend is
    /// about to release the spot. Recovering payment data in that window only produces
    /// a confusing "payment cannot be recovered" dialog while the user is being dropped.
    private static let minimumRecoverableReservationWindow: TimeInterval = 15

    /// True only while the current user holds a reservation with enough time left to
    /// actually pay. Guards both the recovery trigger and the handling of its response.
    private var hasRecoverableReservation: Bool {
        guard let expiry = currentUserReservedUntil else { return false }
        return expiry.timeIntervalSinceNow > Self.minimumRecoverableReservationWindow
    }

    private func recoverPendingPayment() async {
        isRecoveringPayment = true
        let result = await fetchPendingPaymentUseCase.execute(matchId: match.id)
        isRecoveringPayment = false

        // The reservation can expire while the request is in flight — that is exactly
        // when the backend answers 409. Acting on the response then would raise a dialog
        // about a reservation the user no longer has.
        guard hasRecoverableReservation else { return }

        switch result {
        case .recovered(let data):
            joinData = data
            pendingPaymentStore.save(data, matchId: match.id)
            // `.onChange(of: viewModel.joinData)` in the view will handle PaymentSheet setup.

        case .notRecoverable(let message):
            pendingPaymentIssue = .notRecoverable(message ?? L10n.PendingPayment.notRecoverableDefaultMessage)

        case .retryLater(let message):
            pendingPaymentIssue = .retryLater(message ?? L10n.PendingPayment.retryLaterDefaultMessage)

        case .unavailable:
            // Silently unavailable — no user-facing UI fires.
            break
        }
    }

    // MARK: - Leave Match

    func leaveMatch() async {
        isLeaving = true
        leaveError = nil
        do {
            try await leaveMatchUseCase.execute(matchId: match.id)
            clearJoinData()
            matchLeft = true
            NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
        } catch {
            guard !error.isCancellation else {
                isLeaving = false
                return
            }
            leaveError = error.localizedDescription
        }
        isLeaving = false
    }

    func cancelMatch() async {
        isCancelling = true
        cancelError = nil
        do {
            try await cancelMatchUseCase.execute(matchId: match.id)
            clearJoinData()
            matchCancelled = true
            NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
        } catch {
            guard !error.isCancellation else {
                isCancelling = false
                return
            }
            cancelError = error.localizedDescription
        }
        isCancelling = false
    }

    // MARK: - Firestore Live Players (presence & reservation countdown only)

    /// Subscribes to Firestore for the real-time player list, reservation countdown,
    /// and the user's joined state. The "Join / Leave match" button reacts to
    /// `isCurrentUserJoined`, so reflecting Firestore here keeps it in sync automatically
    /// even when the payment-polling flow failed or timed out.
    ///
    /// The payment SUCCESS overlay is NOT driven from here — it listens to the
    /// one-shot `paymentDidSucceed` signal so it only fires right after a real payment.
    func subscribeToPlayers() async {
        // Closed matches (COMPLETED/CANCELED) use a one-shot REST snapshot; others subscribe to Firestore
        if match.matchStatus == .completed || match.matchStatus == .canceled {
            liveTeamAPlayers = match.teamAPlayers
            liveTeamBPlayers = match.teamBPlayers
            return
        }
        let userId = currentUserId()
        do {
            for try await snapshot in subscribePlayersUseCase.execute(matchId: match.id) {
                playersError = nil
                liveTeamAPlayers = snapshot.teamAPlayers
                liveTeamBPlayers = snapshot.teamBPlayers
                if let userId {
                    currentUserReservedUntil = snapshot.reservationsByPlayerId[userId]
                    // Try local cache first, then recover from backend if missing.
                    if hasRecoverableReservation, joinData == nil, !hasAttemptedPendingRecovery {
                        if let cached = pendingPaymentStore.load(matchId: match.id) {
                            // Local cache hit — no network needed.
                            joinData = cached
                        } else {
                            // Local miss — spawn a background recovery task. Running this inside
                            // the for-await would stall the snapshot stream.
                            hasAttemptedPendingRecovery = true
                            Task { await recoverPendingPayment() }
                        }
                    }
                    // The reservation is gone or already dying: drop any recovery dialog raised
                    // for it — the user is being released from the match and can simply join
                    // again, so a "payment cannot be recovered" alert is pure noise — and re-arm
                    // recovery for whatever reservation comes next.
                    if !hasRecoverableReservation {
                        hasAttemptedPendingRecovery = false
                        pendingPaymentIssue = nil
                    }
                    // Always reflect the joined state from Firestore so the action button
                    // auto-switches to "Leave match" the moment the backend confirms the user
                    // is in (regardless of whether payment polling succeeded).
                    let allPlayers = snapshot.teamAPlayers + snapshot.teamBPlayers
                    let wasJoined = isCurrentUserJoined
                    isCurrentUserJoined = allPlayers.contains { $0.playerId == userId && $0.status == .joined }
                    if !wasJoined, isCurrentUserJoined {
                        NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
                    }
                }
            }
        } catch {
            guard !error.isCancellation else { return }
            playersError = error.localizedDescription
        }
    }
}
