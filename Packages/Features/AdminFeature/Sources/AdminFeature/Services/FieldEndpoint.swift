import Foundation
import NetworkFramework

// MARK: - FieldEndpoint

enum FieldEndpoint: APIEndpoint {
    case create
    case byAdmin
    case update
    /// 1.3 Link an existing location to a field.
    case linkLocation(fieldId: String, locationId: String)
    /// 1.4 Delete a field and all its associated data.
    case deleteField(fieldId: String)
    /// 1.6 Fetch all fields returning only id + name (for pickers/dropdowns).
    case idName
    /// 2.1 Upload a new image at a given slot position (0-3).
    case uploadImage(fieldId: String, position: Int)
    /// 2.2 Replace an existing image.
    case updateImage(fieldId: String, imageId: String)
    /// 2.3 Delete an existing image.
    case deleteImage(fieldId: String, imageId: String)
    /// 2.4 Fetch authenticated image data (redirects to signed Cloudinary URL).
    case getImage(imageName: String)

    var path: String {
        switch self {
        case .create:   return "/fields/create"
        case .byAdmin:  return "/fields/by-admin"
        case .update:   return "/fields/update"
        case let .linkLocation(fieldId, locationId):
            return "/fields/\(fieldId)/location/\(locationId)"
        case let .deleteField(fieldId):
            return "/fields/delete/\(fieldId)"
        case .idName:
            return "/fields/id-name"
        case let .uploadImage(fieldId, position):
            return "/fields/\(fieldId)/\(position)/images"
        case let .updateImage(fieldId, imageId):
            return "/fields/image/\(fieldId)/\(imageId)"
        case let .deleteImage(fieldId, imageId):
            return "/fields/delete/image/\(fieldId)/\(imageId)"
        case let .getImage(imageName):
            return "/fields/image/\(imageName)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create:           return .post
        case .byAdmin:          return .get
        case .update:           return .post
        case .linkLocation:     return .put
        case .deleteField:      return .delete
        case .idName:           return .get
        case .uploadImage:      return .post
        case .updateImage:      return .post
        case .deleteImage:      return .delete
        case .getImage:         return .get
        }
    }
}
