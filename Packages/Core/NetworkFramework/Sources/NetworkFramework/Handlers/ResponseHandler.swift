import Foundation

// MARK: - Response Handler Protocol

public protocol ResponseHandler {
    func handleResponse<T: Decodable>(
        _ data: Data,
        _ response: HTTPURLResponse,
        for type: T.Type,
        decoder: JSONDecoder
    ) throws -> T
}

// MARK: - Default Response Handler Implementation

public struct DefaultResponseHandler: ResponseHandler {
    
    public init() {}
    
    public func handleResponse<T: Decodable>(
        _ data: Data,
        _ response: HTTPURLResponse,
        for type: T.Type,
        decoder: JSONDecoder
    ) throws -> T {
        switch response.statusCode {
        case 200...299:
            return try decodeSuccessResponse(data, for: type, decoder: decoder)
        case 400...499:
            throw try decodeErrorResponse(data, statusCode: response.statusCode, decoder: decoder)
        case 500...599:
            throw try decodeErrorResponse(data, statusCode: response.statusCode, decoder: decoder)
        default:
            throw APIError.serverError(statusCode: response.statusCode, title: "", message: "Unexpected status code")
        }
    }
    
    // MARK: - Private Methods
    
    private func decodeSuccessResponse<T: Decodable>(
        _ data: Data,
        for type: T.Type,
        decoder: JSONDecoder
    ) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError("Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    private func decodeErrorResponse(_ data: Data, statusCode: Int, decoder: JSONDecoder) throws -> APIError {
        let parsed = parseErrorDetails(from: data, decoder: decoder)
        
        switch statusCode {
        case 401:
            return APIError.serverError(statusCode: 401, title: parsed.title, message: parsed.message)
        case 404:
            return APIError.notFound
        default:
            return APIError.serverError(statusCode: statusCode, title: parsed.title, message: parsed.message)
        }
    }
    
    private func parseErrorDetails(from data: Data, decoder: JSONDecoder) -> (title: String, message: String) {
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return (errorResponse.error.title, errorResponse.displayMessage)
        }
        
        let fallback = String(data: data, encoding: .utf8) ?? "Unknown error occurred"
        return ("", fallback)
    }
}
