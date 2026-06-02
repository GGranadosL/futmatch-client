import Foundation

// MARK: - Error Models

public struct APIErrorResponse: Decodable {
    public let error: ErrorDetails
    
    // Get the user-friendly message
    public var displayMessage: String {
        error.message.isEmpty ? error.title : error.message
    }
}

public struct ErrorDetails: Decodable {
    public let title: String
    public let message: String
    public let errorCode: String
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class APIClient {
    
    // MARK: - Properties
    
    public static let shared: APIClient = {
        let client = APIClient()
        // Add User-Agent interceptor by default
        client.addInterceptor(UserAgentInterceptor())
        return client
    }()
    
    private let session: URLSession
    private var interceptors: [RequestInterceptor] = []
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<String, Error>] = []
    
    /// Called on every 401 response (before posting the unauthorized notification).
    /// Should fetch a new access token and return it. If it throws, the 401 falls
    /// through to the normal unauthorized handling (notification + logout).
    public var unauthorizedHandler: (() async throws -> String)?
    
    public var logger: NetworkLogger
    
    // MARK: - Initialization
    
    public init(
        session: URLSession = .shared,
        logger: NetworkLogger = ConsoleNetworkLogger()
    ) {
        self.session = session
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
    }
    
    public func request<T: Decodable>(
        endpoint: APIEndpoint,
        body: Encodable? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let request = try await buildRequest(for: endpoint, body: body)
        return try await performRequest(request, expecting: T.self, decoder: decoder)
    }

    /// Upload multipart form-data with a single file field.
    public func upload<T: Decodable>(
        endpoint: APIEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "image",
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try await buildRequest(for: endpoint, body: nil)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await performRequest(request, expecting: T.self, decoder: decoder)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(for endpoint: APIEndpoint, body: Encodable?) async throws -> URLRequest {
        guard let url = endpoint.fullURL else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Add headers using functional approach
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Apply interceptors using higher-order functions
        try await applyInterceptors(to: &request)
        
        // Set body using priority chain
        request.httpBody = try encodeBody(body: body, fallback: endpoint.body)
        
        return request
    }
    
    private func applyInterceptors(to request: inout URLRequest) async throws {
        for interceptor in interceptors {
            try await interceptor.intercept(&request)
        }
    }
    
    private func encodeBody(body: Encodable?, fallback: Data?) throws -> Data? {
        if let body = body {
            return try JSONEncoder().encode(body)
        }
        return fallback
    }
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        expecting type: T.Type,
        decoder: JSONDecoder
    ) async throws -> T {
        
        logger.logRequest(request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logger.logResponse(httpResponse, data: data)
            
            // On 401, attempt a token refresh and retry once before giving up
            if httpResponse.statusCode == 401, let handler = unauthorizedHandler {
                let newToken: String
                if isRefreshing {
                    // Another request is already refreshing — wait for its result
                    newToken = try await withCheckedThrowingContinuation { continuation in
                        refreshContinuations.append(continuation)
                    }
                } else {
                    isRefreshing = true
                    do {
                        newToken = try await handler()
                        // Resume all waiting continuations with the new token
                        let waiting = refreshContinuations
                        refreshContinuations.removeAll()
                        isRefreshing = false
                        for cont in waiting {
                            cont.resume(returning: newToken)
                        }
                    } catch {
                        let waiting = refreshContinuations
                        refreshContinuations.removeAll()
                        isRefreshing = false
                        for cont in waiting {
                            cont.resume(throwing: error)
                        }
                        // Refresh failed — fall through to standard 401 handling below
                        return try handleResponse(data, httpResponse, for: type, decoder: decoder)
                    }
                }
                // Retry with the new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                logger.logRequest(retryRequest)
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                logger.logResponse(retryHTTPResponse, data: retryData)
                return try handleResponse(retryData, retryHTTPResponse, for: type, decoder: decoder)
            }
            
            return try handleResponse(data, httpResponse, for: type, decoder: decoder)
            
        } catch let apiError as APIError {
            logger.logError(apiError)
            throw apiError
        } catch {
            let networkError = APIError.networkError(error)
            logger.logError(networkError)
            throw networkError
        }
    }
    
    // MARK: - Response Handling
    
    private func handleResponse<T: Decodable>(
        _ data: Data,
        _ response: HTTPURLResponse,
        for type: T.Type,
        decoder: JSONDecoder
    ) throws -> T {
        switch response.statusCode {
        case 200...299:
            return try decodeSuccessResponse(data, for: type, decoder: decoder)
        case 401:
            let parsed = parseErrorDetails(from: data, decoder: decoder)
            NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            throw APIError.serverError(statusCode: 401, title: parsed.title, message: parsed.message)
        case 404:
            throw APIError.notFound
        default:
            let parsed = parseErrorDetails(from: data, decoder: decoder)
            throw APIError.serverError(statusCode: response.statusCode, title: parsed.title, message: parsed.message)
        }
    }
    
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
    
    // MARK: - Error Parsing with Higher-Order Functions
    
    private func parseErrorDetails(from data: Data, decoder: JSONDecoder) -> (title: String, message: String) {
        // Try {"error": {"title":…, "message":…}} structure first
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return (errorResponse.error.title, errorResponse.displayMessage)
        }
        // Fallback: server returns flat {"title":…, "message":…} at root level
        if let flat = try? decoder.decode(ErrorDetails.self, from: data) {
            let msg = flat.message.isEmpty ? flat.title : flat.message
            return (flat.title, msg)
        }
        return ("", "Error desconocido")
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted by APIClient whenever any request receives a 401 Unauthorized response.
    static let apiUnauthorized = Notification.Name("com.futmatch.network.unauthorized")
}
