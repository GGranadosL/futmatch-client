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
    /// Machine-readable code (e.g. `PAYMENT_PENDING_NOT_RECOVERABLE`). Optional because
    /// not every backend error body carries it — a non-optional here made those bodies
    /// fail to decode and degrade to a generic "Error desconocido".
    public let errorCode: String?
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class APIClient {
    
    // MARK: - Properties
    
    public static let shared: APIClient = {
        #if DEBUG
        // Use a `.default` config session so Pulse's URLSessionProxy can intercept
        // requests. Pulse swizzles URLSession at the class level, so both
        // URLSession.shared and custom sessions are captured automatically.
        let client = APIClient(
            session: URLSession(configuration: .default),
            logger: DebugNetworkLogger()
        )
        #else
        let client = APIClient()
        #endif
        client.addInterceptor(UserAgentInterceptor())
        return client
    }()
    
    private let session: URLSession
    private var interceptors: [RequestInterceptor] = []
    /// In-flight token refresh, shared by every request that hits a 401 while it runs.
    ///
    /// Deliberately a `Task` and not a `[CheckedContinuation]`: appending to an array
    /// from inside `withCheckedThrowingContinuation` is not atomic with the "is a
    /// refresh running?" check, because that function is nonisolated and releases the
    /// main actor before its closure runs. A late append landed after the refresh had
    /// already drained the array, leaving that request suspended forever with no
    /// response and no error (stuck skeletons on Home). Reading and assigning this
    /// property happens synchronously on the actor, so there is no such window.
    private var refreshTask: Task<String, Error>?
    
    /// Called on every 401 response (before posting the unauthorized notification).
    /// Should fetch a new access token and return it. If it throws, the 401 falls
    /// through to the normal unauthorized handling (notification + logout).
    public var unauthorizedHandler: (() async throws -> String)?
    
    public var logger: NetworkLogger
    
    // MARK: - Initialization
    
    public init(
        session: URLSession = .shared,
        logger: NetworkLogger = SilentNetworkLogger()
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
    
    /// Downloads raw `Data` from an authenticated endpoint.
    /// URLSession follows the 302 redirect automatically, so this works for
    /// endpoints that redirect to signed Cloudinary URLs.
    public func downloadData(endpoint: APIEndpoint) async throws -> Data {
        let request = try await buildRequest(for: endpoint, body: nil)
        logger.logRequest(request)
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            logger.logResponse(httpResponse, data: Data())
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    title: "Error al cargar imagen",
                    message: "No se pudo descargar la imagen.",
                    errorCode: ""
                )
            }
            return data
        } catch let apiError as APIError {
            logger.logError(apiError)
            throw apiError
        } catch {
            let networkError = APIError.networkError(error)
            logger.logError(networkError)
            throw networkError
        }
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
            
            // On 401, refresh the token and retry once before giving up.
            // A 401 on its own never ends the session — see `endSession()`.
            if httpResponse.statusCode == 401, let handler = unauthorizedHandler {
                let newToken: String
                do {
                    newToken = try await refreshedToken(using: handler)
                } catch {
                    // Refresh failed; `refreshedToken` already ended the session.
                    // Report this request's own 401, not the shared refresh error.
                    return try handleResponse(data, httpResponse, for: type, decoder: decoder)
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
                if retryHTTPResponse.statusCode == 401 {
                    // The server rejects a token it issued seconds ago — the retry
                    // budget is spent and there is nothing left to recover with.
                    endSession()
                }
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
    
    /// Returns a fresh access token, coalescing concurrent 401s onto a single refresh.
    ///
    /// A burst of requests failing with 401 at once (Home + notifications + profile +
    /// FCM sync on launch) must produce exactly one refresh call, and every one of them
    /// must be resumed with its result — success or failure. Awaiting the same `Task`
    /// gives both: the check-and-store below runs without an intervening suspension
    /// point, so no caller can arrive too late to observe the in-flight refresh.
    private func refreshedToken(using handler: @escaping () async throws -> String) async throws -> String {
        if let inFlight = refreshTask {
            // A waiter never ends the session itself — the request that owns the
            // refresh does that, so one failed refresh logs out exactly once
            // instead of once per request in the burst.
            return try await inFlight.value
        }
        let task = Task { try await handler() }
        refreshTask = task
        // Only the request that started the refresh clears it, so a later refresh
        // is never cancelled out by a straggler from the previous one.
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch {
            endSession()
            throw error
        }
    }

    /// Ends the session, forcing the user back to login.
    ///
    /// Deliberately **not** called for every 401. A 401 usually means nothing worse
    /// than "this access token just expired", which the refresh below recovers from
    /// transparently. Only two outcomes are unrecoverable and reach this method:
    /// the refresh call itself failed (no refresh token, or the server rejected it),
    /// or a retry carrying a freshly issued token was still rejected.
    private func endSession() {
        NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
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
            // No session teardown here: this runs for every 401, including ones the
            // refresh-and-retry path recovers from. Ending the session is `endSession()`'s
            // job, and only after a refresh has actually been attempted and failed.
            let parsed = parseErrorDetails(from: data, decoder: decoder)
            throw APIError.serverError(
                statusCode: 401,
                title: parsed.title,
                message: parsed.message,
                errorCode: parsed.errorCode
            )
        case 404:
            throw APIError.notFound
        default:
            let parsed = parseErrorDetails(from: data, decoder: decoder)
            throw APIError.serverError(
                statusCode: response.statusCode,
                title: parsed.title,
                message: parsed.message,
                errorCode: parsed.errorCode
            )
        }
    }
    
    private func decodeSuccessResponse<T: Decodable>(
        _ data: Data,
        for type: T.Type,
        decoder: JSONDecoder
    ) throws -> T {
        // No-content endpoints (e.g. DELETE / 204): a 2xx status is success
        // regardless of body shape, so don't attempt to decode it. This avoids
        // spurious decoding failures on empty bodies or `{"data": null}`.
        if type == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError("Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Parsing with Higher-Order Functions
    
    private func parseErrorDetails(
        from data: Data,
        decoder: JSONDecoder
    ) -> (title: String, message: String, errorCode: String) {
        // Try {"error": {"title":…, "message":…, "errorCode":…}} structure first
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return (errorResponse.error.title, errorResponse.displayMessage, errorResponse.error.errorCode ?? "")
        }
        // Fallback: server returns flat {"title":…, "message":…} at root level
        if let flat = try? decoder.decode(ErrorDetails.self, from: data) {
            let msg = flat.message.isEmpty ? flat.title : flat.message
            return (flat.title, msg, flat.errorCode ?? "")
        }
        return ("", "Error desconocido", "")
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted by APIClient whenever any request receives a 401 Unauthorized response.
    static let apiUnauthorized = Notification.Name("com.futmatch.network.unauthorized")
}
