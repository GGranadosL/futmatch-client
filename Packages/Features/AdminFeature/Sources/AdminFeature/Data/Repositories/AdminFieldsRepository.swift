import Foundation

/// API-backed implementation of `AdminFieldsRepositoryProtocol`.
/// Fetches the field list for `scope` (see `FieldListScope`).
struct AdminFieldsRepository: AdminFieldsRepositoryProtocol {
    private let service: FieldServiceProtocol
    private let scope: FieldListScope

    init(service: FieldServiceProtocol, scope: FieldListScope) {
        self.service = service
        self.scope = scope
    }

    func fetchFields() async throws -> [AdminFieldItem] {
        try await service.fetchFields(scope: scope)
    }
}
