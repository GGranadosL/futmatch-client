import Foundation

/// Abstracts field-related data operations.
public protocol FieldRepositoryProtocol {
    func createField(_ params: CreateFieldParams) async throws -> Field
    func updateField(fieldId: String, _ params: CreateFieldParams) async throws
    func deleteField(fieldId: String) async throws
    func linkLocation(fieldId: String, locationId: String) async throws
    func fetchFieldIdNames() async throws -> [FieldIdName]
    /// Uploads a new image at `position`. Returns the new image UUID.
    func uploadFieldImage(fieldId: String, position: Int, imageData: Data) async throws -> String
    /// Replaces an existing image. Returns the updated image UUID.
    func replaceFieldImage(fieldId: String, imageId: String, imageData: Data) async throws -> String
    /// Deletes an existing image.
    func deleteFieldImage(fieldId: String, imageId: String) async throws
    /// Downloads raw image data via the authenticated redirect endpoint.
    func downloadFieldImage(imageName: String) async throws -> Data
}
