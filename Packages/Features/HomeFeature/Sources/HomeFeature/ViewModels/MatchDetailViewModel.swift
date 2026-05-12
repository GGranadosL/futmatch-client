import Foundation
import PersistenceFramework

// MARK: - MatchDetailViewModel

@MainActor
final class MatchDetailViewModel: ObservableObject {
    @Published private(set) var match: MatchItem
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var detailError: String?

    // MARK: - Live Players State

    @Published private(set) var liveTeamAPlayers: [MatchPlayer]?
    @Published private(set) var liveTeamBPlayers: [MatchPlayer]?
    /// Non-nil when the current user has an active RESERVED slot — holds the expiry date.
    @Published private(set) var currentUserReservedUntil: Date?

    // MARK: - Join State

    @Published private(set) var isJoining = false
    @Published private(set) var joinError: String?
    /// Set after a successful join call — holds the Stripe payment data.
    /// Also restored from Keychain when a reservation is found on app relaunch.
    @Published private(set) var joinData: JoinMatchData?

    // MARK: - Cancel State

    @Published private(set) var isCancelling = false
    @Published private(set) var cancelError: String?
    @Published private(set) var matchCancelled = false

    // MARK: - Leave State

    /// True when the current user has a JOINED slot (payment confirmed).
    @Published private(set) var isCurrentUserJoined = false
    @Published private(set) var isLeaving = false
    @Published private(set) var leaveError: String?
    /// Becomes true after a successful leave — view should dismiss.
    @Published private(set) var matchLeft = false

    private let fetchDetailUseCase: FetchMatchDetailUseCaseProtocol
    private let joinMatchUseCase: JoinMatchUseCaseProtocol
    private let subscribePlayersUseCase: SubscribeMatchPlayersUseCaseProtocol
    private let cancelMatchUseCase: CancelMatchUseCaseProtocol
    private let leaveMatchUseCase: LeaveMatchUseCaseProtocol
    private let keychainManager: KeychainManager

    init(
        initialMatch: MatchItem,
        fetchDetailUseCase: FetchMatchDetailUseCaseProtocol,
        joinMatchUseCase: JoinMatchUseCaseProtocol,
        subscribePlayersUseCase: SubscribeMatchPlayersUseCaseProtocol,
        cancelMatchUseCase: CancelMatchUseCaseProtocol,
        leaveMatchUseCase: LeaveMatchUseCaseProtocol,
        keychainManager: KeychainManager = .shared
    ) {
        self.match = initialMatch
        self.fetchDetailUseCase = fetchDetailUseCase
        self.joinMatchUseCase = joinMatchUseCase
        self.subscribePlayersUseCase = subscribePlayersUseCase
        self.cancelMatchUseCase = cancelMatchUseCase
        self.leaveMatchUseCase = leaveMatchUseCase
        self.keychainManager = keychainManager
    }

    func loadDetail() async {
        isLoadingDetail = true
        detailError = nil
        do {
            match = try await fetchDetailUseCase.execute(matchId: match.id)
        } catch {
            detailError = error.localizedDescription
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
            joinData = data
            persistJoinData(data)
        } catch {
            joinError = error.localizedDescription
        }
        isJoining = false
    }

    /// Clears in-memory and persisted join data (call after payment completes or reservation expires).
    func clearJoinData() {
        joinData = nil
        try? keychainManager.delete(forKey: joinDataKeychainKey)
    }

    func clearJoinError() {
        joinError = nil
    }

    func clearCancelError() {
        cancelError = nil
    }

    func clearLeaveError() {
        leaveError = nil
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
            cancelError = error.localizedDescription
        }
        isCancelling = false
    }

    // MARK: - Live Players

    func subscribeToPlayers() async {
        let userId = KeychainManager.shared.userId
        for await snapshot in subscribePlayersUseCase.execute(matchId: match.id) {
            liveTeamAPlayers = snapshot.teamAPlayers
            liveTeamBPlayers = snapshot.teamBPlayers
            if let userId {
                let expiryDate = snapshot.reservationsByPlayerId[userId]
                currentUserReservedUntil = expiryDate
                // Detect JOINED status from Firestore
                let allPlayers = snapshot.teamAPlayers + snapshot.teamBPlayers
                let wasJoined = isCurrentUserJoined
                isCurrentUserJoined = allPlayers.contains { $0.playerId == userId && $0.status == .joined }
                if !wasJoined, isCurrentUserJoined {
                    NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
                }
                // Restore joinData from Keychain when a reservation exists but joinData is not set
                // (happens when the app is relaunched with an active reservation)
                if expiryDate != nil, joinData == nil {
                    restoreJoinDataIfNeeded()
                }
            }
        }
    }

    // MARK: - Private Persistence

    private var joinDataKeychainKey: String { "join_data_\(match.id)" }

    private func persistJoinData(_ data: JoinMatchData) {
        try? keychainManager.saveCodable(data, forKey: joinDataKeychainKey)
    }

    private func restoreJoinDataIfNeeded() {
        guard joinData == nil else { return }
        joinData = try? keychainManager.loadCodable(JoinMatchData.self, forKey: joinDataKeychainKey)
    }

}
