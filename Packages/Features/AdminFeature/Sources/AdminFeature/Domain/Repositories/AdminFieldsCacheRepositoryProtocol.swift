import Foundation

public protocol AdminFieldsCacheRepositoryProtocol {
    func saveFields(_ items: [AdminFieldItem]) throws
    func loadFields() -> [AdminFieldItem]
    func clearFields() throws
}
