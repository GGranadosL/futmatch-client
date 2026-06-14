import Foundation

/// Concrete `FieldRepositoryProtocol` backed by the API via `FieldService`.
struct FieldRepository: FieldRepositoryProtocol {
    private let service: FieldServiceProtocol

    init(service: FieldServiceProtocol) {
        self.service = service
    }

    func createField(_ params: CreateFieldParams) async throws -> Field {
        try await service.createField(CreateFieldRequest(params: params))
    }

    func updateField(fieldId: String, _ params: CreateFieldParams) async throws {
        try await service.updateField(UpdateFieldRequest(fieldId: fieldId, params: params))
    }

    func uploadFieldImage(fieldId: String, position: Int, imageData: Data) async throws -> String {
        try await service.uploadFieldImage(fieldId: fieldId, position: position, imageData: imageData)
    }

    func replaceFieldImage(fieldId: String, imageId: String, imageData: Data) async throws -> String {
        try await service.replaceFieldImage(fieldId: fieldId, imageId: imageId, imageData: imageData)
    }

    func deleteFieldImage(fieldId: String, imageId: String) async throws {
        try await service.deleteFieldImage(fieldId: fieldId, imageId: imageId)
    }

    func deleteField(fieldId: String) async throws {
        try await service.deleteField(fieldId: fieldId)
    }

    func linkLocation(fieldId: String, locationId: String) async throws {
        try await service.linkLocation(fieldId: fieldId, locationId: locationId)
    }

    func fetchFieldIdNames() async throws -> [FieldIdName] {
        try await service.fetchFieldIdNames()
    }

    func downloadFieldImage(imageName: String) async throws -> Data {
        try await service.downloadFieldImage(imageName: imageName)
    }
}
