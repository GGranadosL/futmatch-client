import Foundation
import NetworkFramework

// MARK: - Protocol

protocol FieldServiceProtocol {
    func createField(_ request: CreateFieldRequest) async throws -> Field
    func fetchFieldsByAdmin() async throws -> [AdminFieldItem]
    func updateField(_ request: UpdateFieldRequest) async throws
    func deleteField(fieldId: String) async throws
    func linkLocation(fieldId: String, locationId: String) async throws
    func fetchFieldIdNames() async throws -> [FieldIdName]
    /// Uploads a new image at `position`. Returns the new image UUID.
    func uploadFieldImage(fieldId: String, position: Int, imageData: Data) async throws -> String
    /// Replaces an existing image. Returns the updated image UUID.
    func replaceFieldImage(fieldId: String, imageId: String, imageData: Data) async throws -> String
    /// Deletes an existing image.
    func deleteFieldImage(fieldId: String, imageId: String) async throws
    /// Downloads raw image data from the authenticated Cloudinary redirect endpoint.
    func downloadFieldImage(imageName: String) async throws -> Data
}

// MARK: - Implementation

struct FieldService: FieldServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func createField(_ request: CreateFieldRequest) async throws -> Field {
        let response: CreateFieldResponse = try await apiClient.request(
            endpoint: FieldEndpoint.create,
            body: request
        )
        return response.data.toDomain()
    }

    func fetchFieldsByAdmin() async throws -> [AdminFieldItem] {
        let response: AdminFieldsResponse = try await apiClient.request(
            endpoint: FieldEndpoint.byAdmin
        )
        return response.data.map { $0.toDomain() }
    }

    func updateField(_ request: UpdateFieldRequest) async throws {
        let _: UpdateFieldResponse = try await apiClient.request(
            endpoint: FieldEndpoint.update,
            body: request
        )
    }

    func uploadFieldImage(fieldId: String, position: Int, imageData: Data) async throws -> String {
        // NOTE: the API docs show `--form "file=@..."`, but the server rejects
        // that part name ("Discarding multipart file part due to invalid name:
        // name=file"). The backend expects the part to be named "image" — same
        // as the profile-picture upload endpoint.
        let response: FieldImageMutationResponse = try await apiClient.upload(
            endpoint: FieldEndpoint.uploadImage(fieldId: fieldId, position: position),
            fileData: imageData,
            fileName: "field-image.jpg",
            mimeType: "image/jpeg",
            fieldName: "image"
        )
        return response.data
    }

    func replaceFieldImage(fieldId: String, imageId: String, imageData: Data) async throws -> String {
        let response: FieldImageMutationResponse = try await apiClient.upload(
            endpoint: FieldEndpoint.updateImage(fieldId: fieldId, imageId: imageId),
            fileData: imageData,
            fileName: "field-image.jpg",
            mimeType: "image/jpeg",
            fieldName: "image"
        )
        return response.data
    }

    func deleteFieldImage(fieldId: String, imageId: String) async throws {
        let _: FieldImageMutationResponse = try await apiClient.request(
            endpoint: FieldEndpoint.deleteImage(fieldId: fieldId, imageId: imageId)
        )
    }

    func deleteField(fieldId: String) async throws {
        struct DeleteFieldResponse: Decodable { let data: String }
        let _: DeleteFieldResponse = try await apiClient.request(
            endpoint: FieldEndpoint.deleteField(fieldId: fieldId)
        )
    }

    func linkLocation(fieldId: String, locationId: String) async throws {
        struct LinkResponse: Decodable { let data: Bool }
        let _: LinkResponse = try await apiClient.request(
            endpoint: FieldEndpoint.linkLocation(fieldId: fieldId, locationId: locationId)
        )
    }

    func fetchFieldIdNames() async throws -> [FieldIdName] {
        struct Response: Decodable { let data: [FieldIdNameDTO] }
        let response: Response = try await apiClient.request(endpoint: FieldEndpoint.idName)
        return response.data.map { FieldIdName(id: $0.id, name: $0.name) }
    }

    func downloadFieldImage(imageName: String) async throws -> Data {
        try await apiClient.downloadData(endpoint: FieldEndpoint.getImage(imageName: imageName))
    }
}
