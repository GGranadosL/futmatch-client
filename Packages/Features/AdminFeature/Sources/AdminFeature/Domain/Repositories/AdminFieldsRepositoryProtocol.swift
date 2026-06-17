import Foundation

public protocol AdminFieldsRepositoryProtocol {
    func fetchFields() async throws -> [AdminFieldItem]
}
