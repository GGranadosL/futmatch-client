import Foundation

/// Placeholder repository — returns representative data so the fields list
/// screen can be built and reviewed before the backend endpoint is available.
/// Replace with `AdminFieldsRepository` (API-backed) in the factory once the
/// GET /fields endpoint exists.
struct PreviewAdminFieldsRepository: AdminFieldsRepositoryProtocol {
    func fetchFields() async throws -> [AdminFieldItem] {
        [
            AdminFieldItem(
                id: "1",
                name: "Arena Park Central",
                priceInCents: 3800,
                capacity: 12,
                address: "Av. Central 452"
            ),
            AdminFieldItem(
                id: "2",
                name: "Arena Park Central",
                priceInCents: 3800,
                capacity: 12,
                address: "Av. Central 452"
            ),
            AdminFieldItem(
                id: "3",
                name: "Arena Park Central",
                priceInCents: 3800,
                capacity: 12,
                address: "Av. Central 452"
            ),
        ]
    }
}
