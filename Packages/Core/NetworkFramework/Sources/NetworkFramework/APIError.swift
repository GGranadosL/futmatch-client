import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(String)
    case serverError(statusCode: Int, title: String, message: String)
    case networkError(Error)
    case unauthorized
    case notFound
    case unknown
    
    /// User-friendly error title (e.g. "Credenciales inválidas")
    public var errorTitle: String {
        switch self {
        case .serverError(_, let title, _):
            return title.isEmpty ? "Error" : title
        default:
            return "Error"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta del servidor inválida"
        case .decodingError(let message):
            return "Error al procesar datos: \(message)"
        case .serverError(_, _, let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "No autorizado"
        case .notFound:
            return "No encontrado"
        case .unknown:
            return "Error desconocido"
        }
    }
}

// MARK: - API-provided error text

public extension Error {
    /// The API-provided error title (e.g. "Token inválido"), when this error is
    /// a server error that carries one. `nil` for non-API or empty titles, so
    /// callers can fall back to a generic localized string.
    var apiErrorTitle: String? {
        guard let apiError = self as? APIError,
              case let .serverError(_, title, _) = apiError,
              !title.isEmpty else { return nil }
        return title
    }

    /// The API-provided error message, when this error is a server error that
    /// carries one. `nil` for non-API or empty messages.
    var apiErrorMessage: String? {
        guard let apiError = self as? APIError,
              case let .serverError(_, _, message) = apiError,
              !message.isEmpty else { return nil }
        return message
    }
}
