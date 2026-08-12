import Foundation

public protocol AccountRepositoryProtocol {
    func deleteAccount(password: String) async throws
}
