import Foundation
import Combine

// MARK: - Goals Storage

/// Persists per-player goal counts to UserDefaults, keyed by matchId.
/// This survives app termination so the admin can resume counting goals.
struct MatchGoalsStorage {
    private let goalsKey: String
    private let bestPlayerKey: String
    private let absentKey: String

    init(matchId: String) {
        self.goalsKey = "supervision_goals_\(matchId)"
        self.bestPlayerKey = "supervision_bestPlayer_\(matchId)"
        self.absentKey = "supervision_absent_\(matchId)"
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

    var absentPlayerIds: [String] {
        get { UserDefaults.standard.stringArray(forKey: absentKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: absentKey) }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: goalsKey)
        UserDefaults.standard.removeObject(forKey: bestPlayerKey)
        UserDefaults.standard.removeObject(forKey: absentKey)
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

    /// playerIds of enrolled players marked as absent (NO_SHOW). Persisted across launches.
    @Published var absentPlayerIds: Set<String> = []

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
        self.absentPlayerIds = Set(storage.absentPlayerIds)
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

    /// Registered (non-external), present players eligible for the Best Player dropdown.
    /// Absent players cannot be MVP, so they are excluded.
    var allPlayers: [AdminMatchPlayer] {
        (teamAPlayers + teamBPlayers).filter { !$0.isExternal && !isAbsent($0) }
    }

    func goalCount(for player: AdminMatchPlayer) -> Int {
        goals[player.playerId] ?? 0
    }

    func isAbsent(_ player: AdminMatchPlayer) -> Bool {
        absentPlayerIds.contains(player.playerId)
    }

    // MARK: - Actions

    func addGoal(to player: AdminMatchPlayer) {
        // Absent players cannot score.
        guard !isAbsent(player) else { return }
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

    /// Toggles a registered player's attendance. Marking a player absent (NO_SHOW)
    /// clears their goals and drops them as MVP, since the backend rejects both.
    func toggleAbsence(for player: AdminMatchPlayer) {
        guard !player.isExternal else { return }
        if absentPlayerIds.contains(player.playerId) {
            absentPlayerIds.remove(player.playerId)
        } else {
            absentPlayerIds.insert(player.playerId)
            if goals[player.playerId] != nil {
                goals[player.playerId] = 0
                storage.goals = goals
            }
            if bestPlayerId == player.playerId {
                setBestPlayer(nil)
            }
        }
        storage.absentPlayerIds = Array(absentPlayerIds)
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
            guard !error.isCancellation else { return }
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
            // Absent (NO_SHOW) players cannot carry goals — they are reported via
            // absentPlayerIds instead and must not appear in the goals array.
            let playerGoals = allPlayers
                .filter { !$0.isExternal && !isAbsent($0) }
                .map { CompleteMatchParams.PlayerGoal(userId: $0.playerId, goals: goals[$0.playerId] ?? 0) }

            // External goals use the stable fixed IDs, not Firestore player entries.
            let externalAGoals = goals[Self.externalAId] ?? 0
            let externalBGoals = goals[Self.externalBId] ?? 0

            var externalGoals: [CompleteMatchParams.ExternalTeamGoals] = []
            if externalAGoals > 0 { externalGoals.append(.init(team: "A", goals: externalAGoals)) }
            if externalBGoals > 0 { externalGoals.append(.init(team: "B", goals: externalBGoals)) }

            // Only send absent IDs for players still present in the lineup.
            let registeredIds = Set(allPlayers.filter { !$0.isExternal }.map { $0.playerId })
            let absentIds = absentPlayerIds.filter { registeredIds.contains($0) }

            let params = CompleteMatchParams(
                matchId: match.id,
                bestPlayerId: mvpId,
                playerGoals: playerGoals,
                externalGoals: externalGoals,
                absentPlayerIds: Array(absentIds)
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
