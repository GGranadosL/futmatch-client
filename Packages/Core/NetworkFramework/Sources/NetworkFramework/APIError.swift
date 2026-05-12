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
