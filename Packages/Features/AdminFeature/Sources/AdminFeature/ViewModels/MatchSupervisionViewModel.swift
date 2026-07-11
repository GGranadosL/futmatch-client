import Foundation
import Combine

// MARK: - Goals Storage

/// Persists per-player goal counts to UserDefaults, keyed by matchId.
/// This survives app termination so the admin can resume counting goals.
struct MatchGoalsStorage {
    private let goalsKey: String
    private let bestPlayerKey: String

    init(matchId: String) {
        self.goalsKey = "supervision_goals_\(matchId)"
        self.bestPlayerKey = "supervision_bestPlayer_\(matchId)"
    }

    var goals: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: goalsKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: goalsKey) }
    }

    var bestPlayerId: String? {
        get { UserDefaults.standard.string(forKey: bestPlayerKey) }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: bestPlayerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: bestPlayerKey)
            }
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: goalsKey)
        UserDefaults.standard.removeObject(forKey: bestPlayerKey)
    }
}

// MARK: - MatchSupervisionViewModel

@MainActor
final class MatchSupervisionViewModel: ObservableObject {

    let match: AdminMatch

    /// Live registered players from Firestore. External rows are appended after each update.
    @Published private(set) var teamAPlayers: [AdminMatchPlayer] = []
    @Published private(set) var teamBPlayers: [AdminMatchPlayer] = []

    /// True once the first Firestore snapshot arrives (registered players loaded).
    @Published private(set) var registeredPlayersLoaded = false
    /// Non-nil when Firestore player stream fails.
    @Published var playersError: String?

    /// playerId → goal count. Persisted across app launches.
    @Published var goals: [String: Int] = [:]

    /// The player selected as Best Player of the match.
    @Published var bestPlayerId: String? = nil

    /// True once `match.endDate` has passed — enables the Finalizar button.
    @Published private(set) var isMatchEnded: Bool = false

    @Published private(set) var isCompleting = false
    @Published var completeError: String? = nil
    @Published private(set) var completeSucceeded = false

    // Fixed local players — always visible, never depend on Firestore.
    // IDs are stable so goal counts persist across sessions.
    static let externalAId = "external_team_A"
    static let externalBId = "external_team_B"

    private let externalA: AdminMatchPlayer
    private let externalB: AdminMatchPlayer

    private let subscribeUseCase: SubscribeAdminMatchPlayersUseCaseProtocol
    private let completeUseCase: CompleteMatchUseCaseProtocol
    private var storage: MatchGoalsStorage
    private var endCheckTimer: Timer? = nil

    init(
        match: AdminMatch,
        subscribeUseCase: SubscribeAdminMatchPlayersUseCaseProtocol,
        completeUseCase: CompleteMatchUseCaseProtocol
    ) {
        self.match = match
        self.subscribeUseCase = subscribeUseCase
        self.completeUseCase = completeUseCase
        self.storage = MatchGoalsStorage(matchId: match.id)
        self.goals = storage.goals
        self.bestPlayerId = storage.bestPlayerId
        self.isMatchEnded = Date() >= match.endDate

        let extA = AdminMatchPlayer(id: MatchSupervisionViewModel.externalAId,
                                    playerId: MatchSupervisionViewModel.externalAId,
                                    name: "", isExternal: true)
        let extB = AdminMatchPlayer(id: MatchSupervisionViewModel.externalBId,
                                    playerId: MatchSupervisionViewModel.externalBId,
                                    name: "", isExternal: true)
        self.externalA = extA
        self.externalB = extB

        // External rows are always present from the start — no Firestore wait.
        self.teamAPlayers = [extA]
        self.teamBPlayers = [extB]
    }

    // MARK: - Computed

    /// Registered (non-external) players for the Best Player dropdown.
    var allPlayers: [AdminMatchPlayer] {
        (teamAPlayers + teamBPlayers).filter { !$0.isExternal }
    }

    func goalCount(for player: AdminMatchPlayer) -> Int {
        goals[player.playerId] ?? 0
    }

    // MARK: - Actions

    func addGoal(to player: AdminMatchPlayer) {
        goals[player.playerId, default: 0] += 1
        storage.goals = goals
    }

    func removeGoal(from player: AdminMatchPlayer) {
        let current = goals[player.playerId] ?? 0
        guard current > 0 else { return }
        goals[player.playerId] = current - 1
        storage.goals = goals
    }

    func setBestPlayer(_ playerId: String?) {
        bestPlayerId = playerId
        storage.bestPlayerId = playerId
    }

    func clearCompleteError() { completeError = nil }

    /// True when all preconditions are met to submit: match ended + best player selected.
    var canFinalize: Bool { isMatchEnded && bestPlayerId != nil && !isCompleting }

    // MARK: - Async Tasks

    func subscribeToPlayers() async {
        do {
            for try await snapshot in subscribeUseCase.execute(matchId: match.id) {
                playersError = nil
                // Registered players come first, external row is pinned at the bottom.
                teamAPlayers = snapshot.teamAPlayers + [externalA]
                teamBPlayers = snapshot.teamBPlayers + [externalB]
                registeredPlayersLoaded = true
            }
        } catch {
            guard !(error is CancellationError) else { return }
            playersError = error.localizedDescription
        }
    }

    func startEndTimeMonitoring() {
        updateMatchEndedState()
        guard !isMatchEnded else { return }
        endCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMatchEndedState()
            }
        }
    }

    func stopEndTimeMonitoring() {
        endCheckTimer?.invalidate()
        endCheckTimer = nil
    }

    func finalizeMatch() async {
        guard let mvpId = bestPlayerId, !mvpId.isEmpty else {
            completeError = L10n.MatchSupervision.bestPlayerRequired
            return
        }
        isCompleting = true
        completeError = nil
        do {
            let allPlayers = teamAPlayers + teamBPlayers
            let playerGoals = allPlayers
                .filter { !$0.isExternal }
                .map { CompleteMatchParams.PlayerGoal(userId: $0.playerId, goals: goals[$0.playerId] ?? 0) }

            // External goals use the stable fixed IDs, not Firestore player entries.
            let externalAGoals = goals[Self.externalAId] ?? 0
            let externalBGoals = goals[Self.externalBId] ?? 0

            var externalGoals: [CompleteMatchParams.ExternalTeamGoals] = []
            if externalAGoals > 0 { externalGoals.append(.init(team: "A", goals: externalAGoals)) }
            if externalBGoals > 0 { externalGoals.append(.init(team: "B", goals: externalBGoals)) }

            let params = CompleteMatchParams(
                matchId: match.id,
                bestPlayerId: mvpId,
                playerGoals: playerGoals,
                externalGoals: externalGoals
            )
            try await completeUseCase.execute(params: params)
            storage.clear()
            completeSucceeded = true
        } catch {
            completeError = error.localizedDescription
        }
        isCompleting = false
    }

    // MARK: - Private

    private func updateMatchEndedState() {
        guard Date() >= match.endDate else { return }
        isMatchEnded = true
        stopEndTimeMonitoring()
    }
}
