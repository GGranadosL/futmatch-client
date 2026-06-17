import Foundation

/// API-backed implementation of `AdminFieldsRepositoryProtocol`.
/// Calls `GET /fields/by-admin` and maps the response to `AdminFieldItem` list.
struct AdminFieldsRepository: AdminFieldsRepositoryProtocol {
    private let service: FieldServiceProtocol

    init(service: FieldServiceProtocol) {
        self.service = service
    }

    func fetchFields() async throws -> [AdminFieldItem] {
        try await service.fetchFieldsByAdmin()
    }
}
