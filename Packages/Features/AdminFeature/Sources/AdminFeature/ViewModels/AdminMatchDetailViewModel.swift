import Foundation

@MainActor
final class AdminMatchDetailViewModel: ObservableObject {

    let match: AdminMatch

    @Published private(set) var field: AdminFieldItem?
    @Published private(set) var liveTeamAPlayers: [AdminMatchPlayer]?
    @Published private(set) var liveTeamBPlayers: [AdminMatchPlayer]?
    /// Non-nil when Firestore player stream fails.
    @Published var playersError: String?

    @Published private(set) var isCanceling = false
    @Published private(set) var cancelError: String?
    @Published private(set) var cancelSucceeded = false

    @Published private(set) var isRebalancing = false
    @Published var rebalanceError: String?

    private let fetchFieldsUseCase: FetchAdminFieldsUseCaseProtocol
    private let subscribeUseCase: SubscribeAdminMatchPlayersUseCaseProtocol
    private let cancelUseCase: CancelAdminMatchUseCaseProtocol
    private let fetchPlayersUseCase: FetchAdminMatchPlayersUseCaseProtocol
    private let rebalanceUseCase: RebalanceTeamsUseCaseProtocol
    private let remoteConfig: AdminRemoteConfigProtocol

    init(
        match: AdminMatch,
        fetchFieldsUseCase: FetchAdminFieldsUseCaseProtocol,
        subscribeUseCase: SubscribeAdminMatchPlayersUseCaseProtocol,
        cancelUseCase: CancelAdminMatchUseCaseProtocol,
        fetchPlayersUseCase: FetchAdminMatchPlayersUseCaseProtocol,
        rebalanceUseCase: RebalanceTeamsUseCaseProtocol,
        remoteConfig: AdminRemoteConfigProtocol = AdminRemoteConfig()
    ) {
        self.match = match
        self.fetchFieldsUseCase = fetchFieldsUseCase
        self.subscribeUseCase = subscribeUseCase
        self.cancelUseCase = cancelUseCase
        self.fetchPlayersUseCase = fetchPlayersUseCase
        self.rebalanceUseCase = rebalanceUseCase
        self.remoteConfig = remoteConfig
    }

    var rules: [String] {
        guard let raw = field?.rules else { return [] }
        return FieldRulesFormatter.parse(raw)
    }

    /// True when the match is within the paid-threshold window — cancellation will trigger refunds.
    var isInPaidWindow: Bool {
        let hoursUntilMatch = match.startDate.timeIntervalSinceNow / 3_600
        return hoursUntilMatch < Double(remoteConfig.cancelMatchPaidThresholdHours)
    }

    func loadField() async {
        do {
            let fields = try await fetchFieldsUseCase.execute()
            field = fields.first { $0.id == match.fieldId }
        } catch {}
    }

    private var isFinalState: Bool {
        match.status == .canceled || match.status == .completed
    }

    func subscribeToPlayers() async {
        if isFinalState {
            do {
                let (a, b) = try await fetchPlayersUseCase.execute(matchId: match.id)
                liveTeamAPlayers = a
                liveTeamBPlayers = b
            } catch {
                guard !(error is CancellationError) else { return }
                playersError = error.localizedDescription
            }
            return
        }
        do {
            for try await snapshot in subscribeUseCase.execute(matchId: match.id) {
                playersError = nil
                liveTeamAPlayers = snapshot.teamAPlayers
                liveTeamBPlayers = snapshot.teamBPlayers
            }
        } catch {
            guard !(error is CancellationError) else { return }
            playersError = error.localizedDescription
        }
    }

    func cancelMatch(reason: String) async {
        isCanceling = true
        cancelError = nil
        do {
            try await cancelUseCase.execute(matchId: match.id, reason: reason)
            cancelSucceeded = true
        } catch {
            cancelError = error.localizedDescription
        }
        isCanceling = false
    }

    func clearCancelError() { cancelError = nil }
    func clearRebalanceError() { rebalanceError = nil }

    /// Moves `player` to `targetTeam`, optionally swapping with `swapTarget`.
    /// Performs an optimistic local update and rolls back on API failure.
    func movePlayer(_ player: AdminMatchPlayer, toTeam targetTeam: String, swappingWith swapTarget: AdminMatchPlayer? = nil) async {
        let sourceTeam: String
        if liveTeamAPlayers?.contains(player) == true { sourceTeam = "A" }
        else if liveTeamBPlayers?.contains(player) == true { sourceTeam = "B" }
        else { return }

        guard sourceTeam != targetTeam else { return }

        let previousA = liveTeamAPlayers
        let previousB = liveTeamBPlayers

        // Optimistic update
        var newA = liveTeamAPlayers ?? []
        var newB = liveTeamBPlayers ?? []

        if sourceTeam == "A" {
            newA.removeAll { $0.id == player.id }
            newB.append(player)
        } else {
            newB.removeAll { $0.id == player.id }
            newA.append(player)
        }
        if let swap = swapTarget {
            if targetTeam == "A" {
                newA.removeAll { $0.id == swap.id }
                newB.append(swap)
            } else {
                newB.removeAll { $0.id == swap.id }
                newA.append(swap)
            }
        }
        liveTeamAPlayers = newA
        liveTeamBPlayers = newB

        var assignments: [(userId: String, team: String)] = [(userId: player.playerId, team: targetTeam)]
        if let swap = swapTarget {
            assignments.append((userId: swap.playerId, team: sourceTeam))
        }

        isRebalancing = true
        do {
            try await rebalanceUseCase.execute(matchId: match.id, assignments: assignments)
        } catch {
            liveTeamAPlayers = previousA
            liveTeamBPlayers = previousB
            rebalanceError = L10n.AdminMatchDetail.rebalanceError
        }
        isRebalancing = false
    }
}
