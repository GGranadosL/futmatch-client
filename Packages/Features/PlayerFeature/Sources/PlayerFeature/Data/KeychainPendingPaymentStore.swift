import Foundation
import PersistenceFramework

/// Keychain-backed implementation of PendingPaymentStoreProtocol.
/// Uses the same key format as the previous direct Keychain calls so that
/// reservations active on installed builds continue to work after refactoring.
struct KeychainPendingPaymentStore: PendingPaymentStoreProtocol {
    private let keychainManager: KeychainManager

    init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager
    }

    func load(matchId: String) -> JoinMatchData? {
        let key = keyFor(matchId: matchId)
        return try? keychainManager.loadCodable(JoinMatchData.self, forKey: key)
    }

    func save(_ data: JoinMatchData, matchId: String) {
        let key = keyFor(matchId: matchId)
        try? keychainManager.saveCodable(data, forKey: key)
    }

    func clear(matchId: String) {
        let key = keyFor(matchId: matchId)
        try? keychainManager.delete(forKey: key)
    }

    private func keyFor(matchId: String) -> String {
        "join_data_\(matchId)"
    }
}
