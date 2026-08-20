import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(String)
    /// `errorCode` is the backend's machine-readable code (e.g. `PAYMENT_PENDING_NOT_RECOVERABLE`).
    /// Empty when the response body didn't carry one.
    case serverError(statusCode: Int, title: String, message: String, errorCode: String)
    case networkError(Error)
    case unauthorized
    case notFound
    case unknown

    /// User-friendly error title (e.g. "Credenciales inválidas")
    public var errorTitle: String {
        switch self {
        case .serverError(_, let title, _, _):
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
        case .serverError(_, _, let message, _):
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
              case let .serverError(_, title, _, _) = apiError,
              !title.isEmpty else { return nil }
        return title
    }

    /// The API-provided error message, when this error is a server error that
    /// carries one. `nil` for non-API or empty messages.
    var apiErrorMessage: String? {
        guard let apiError = self as? APIError,
              case let .serverError(_, _, message, _) = apiError,
              !message.isEmpty else { return nil }
        return message
    }

    /// The backend's machine-readable error code (e.g. `PAYMENT_PENDING_NOT_RECOVERABLE`).
    /// Prefer this over `apiStatusCode` when branching on a specific failure the
    /// backend documents by name. `nil` for non-API errors or empty codes.
    var apiErrorCode: String? {
        guard let apiError = self as? APIError,
              case let .serverError(_, _, _, errorCode) = apiError,
              !errorCode.isEmpty else { return nil }
        return errorCode
    }

    /// True for a cancelled request, whether it surfaces as Swift's own
    /// `CancellationError`, a cancelled `URLSession` task (`URLError.cancelled`),
    /// or either of those wrapped in `APIError.networkError` by `APIClient`.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        if let apiError = self as? APIError, case let .networkError(underlying) = apiError {
            return underlying.isCancellation
        }
        return false
    }

    /// The HTTP status code behind this error. Use as a fallback when the backend
    /// didn't send an `errorCode`. `.notFound` reports 404 — `APIClient` collapses
    /// 404 responses into that case and discards the body.
    var apiStatusCode: Int? {
        guard let apiError = self as? APIError else { return nil }
        switch apiError {
        case .serverError(let statusCode, _, _, _):
            return statusCode
        case .notFound:
            return 404
        case .unauthorized:
            return 401
        default:
            return nil
        }
    }
}
